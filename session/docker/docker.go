// ABOUTME: Main Docker container management file for claude-squad
// Handles creation, attachment, detachment, and lifecycle of Docker containers

package docker

import (
	"bytes"
	"claude-squad/cmd"
	"claude-squad/log"
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/mount"
	"github.com/docker/docker/client"
	"github.com/docker/docker/pkg/stdcopy"
)

const ProgramClaude = "claude"
const ProgramAider = "aider"
const ProgramGemini = "gemini"

// DockerContainer represents a managed Docker container
type DockerContainer struct {
	// Initialized by NewDockerContainer
	//
	// The name of the container and the sanitized name used for Docker commands.
	sanitizedName string
	program       string
	// Docker client for API operations
	dockerClient *client.Client
	// cmdExec is used to execute commands in the container
	cmdExec cmd.Executor
	// customImage allows overriding the default image selection
	customImage string

	// Initialized by Start or Restore
	//
	// containerID is the ID of the running container
	containerID string
	// monitor monitors the container output and sends signals to the UI when its status changes
	monitor *statusMonitor

	// Initialized by Attach
	// Deinitialized by Detach
	//
	// Channel to be closed at the very end of detaching. Used to signal callers.
	attachCh chan struct{}
	// hijackedResponse is the connection for attached container streams
	hijackedResponse types.HijackedResponse
	// While attached, we use some goroutines to manage stdin/stdout. This stuff
	// is used to terminate them on Detach. We don't want them to outlive the attached window.
	ctx    context.Context
	cancel func()
	wg     *sync.WaitGroup
}

const ContainerPrefix = "claudesquad_"

func toClaudeSquadContainerName(str string) string {
	str = strings.ReplaceAll(str, " ", "")
	str = strings.ReplaceAll(str, ".", "_")
	return fmt.Sprintf("%s%s", ContainerPrefix, str)
}

// NewDockerContainer creates a new DockerContainer with the given name and program.
func NewDockerContainer(name string, program string) (*DockerContainer, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, fmt.Errorf("failed to create Docker client: %w", err)
	}

	return newDockerContainer(name, program, cli, cmd.MakeExecutor()), nil
}

// NewDockerContainerWithImage creates a new DockerContainer with a custom Docker image.
func NewDockerContainerWithImage(name string, program string, dockerImage string) (*DockerContainer, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, fmt.Errorf("failed to create Docker client: %w", err)
	}

	container := newDockerContainer(name, program, cli, cmd.MakeExecutor())
	container.customImage = dockerImage
	return container, nil
}

func newDockerContainer(name string, program string, dockerClient *client.Client, cmdExec cmd.Executor) *DockerContainer {
	return &DockerContainer{
		sanitizedName: toClaudeSquadContainerName(name),
		program:       program,
		dockerClient:  dockerClient,
		cmdExec:       cmdExec,
	}
}

// ensureImageExists builds the Docker image if it doesn't exist locally
func (d *DockerContainer) ensureImageExists() error {
	ctx := context.Background()
	imageName := d.getDockerImage()
	
	// Check if image exists locally
	_, _, err := d.dockerClient.ImageInspectWithRaw(ctx, imageName)
	if err == nil {
		// Image exists, nothing to do
		return nil
	}
	
	// Image doesn't exist, need to build it
	log.InfoLog.Printf("Building Docker image: %s", imageName)
	
	// Get the project root directory (assuming we're in session/docker)
	projectRoot, err := getProjectRoot()
	if err != nil {
		return fmt.Errorf("failed to find project root: %w", err)
	}
	
	// Use the enhanced Dockerfile
	dockerfilePath := filepath.Join(projectRoot, "docker", "Dockerfile")
	
	// Get git config for build args
	gitUserName, _ := exec.Command("git", "config", "--global", "--get", "user.name").Output()
	gitUserEmail, _ := exec.Command("git", "config", "--global", "--get", "user.email").Output()
	currentUser, _ := user.Current()
	
	// Build args for user matching and git config
	buildArgs := fmt.Sprintf("--build-arg USER_UID=%s --build-arg USER_GID=%s", currentUser.Uid, currentUser.Gid)
	if len(gitUserName) > 0 {
		buildArgs += fmt.Sprintf(" --build-arg GIT_USER_NAME=%q", strings.TrimSpace(string(gitUserName)))
	}
	if len(gitUserEmail) > 0 {
		buildArgs += fmt.Sprintf(" --build-arg GIT_USER_EMAIL=%q", strings.TrimSpace(string(gitUserEmail)))
	}
	
	// Build the image using docker build command
	buildCmd := fmt.Sprintf("docker build %s -t %s -f %s %s", buildArgs, imageName, dockerfilePath, filepath.Join(projectRoot, "docker"))
	if err := d.cmdExec.Run(exec.Command("sh", "-c", buildCmd)); err != nil {
		return fmt.Errorf("failed to build Docker image %s: %w", imageName, err)
	}
	
	log.InfoLog.Printf("Successfully built Docker image: %s", imageName)
	return nil
}

// getProjectRoot finds the project root directory by looking for go.mod
func getProjectRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	
	for {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir, nil
		}
		
		parent := filepath.Dir(dir)
		if parent == dir {
			// Reached filesystem root
			break
		}
		dir = parent
	}
	
	return "", errors.New("could not find project root (go.mod not found)")
}

// getDockerImage returns the appropriate Docker image for the program
func (d *DockerContainer) getDockerImage() string {
	// If a custom image was specified, use that
	if d.customImage != "" {
		return d.customImage
	}

	// All programs now use the enhanced claude-squad image
	return "claudesquad/enhanced:latest"
}

// GetDockerImageWithConfig returns the Docker image for the program using config mappings
func GetDockerImageWithConfig(program string, configMappings map[string]string) string {
	// Check config mappings first
	if configMappings != nil {
		// Try exact match first
		if image, ok := configMappings[program]; ok {
			return image
		}
		
		// Try prefix match for programs with arguments
		for configProgram, image := range configMappings {
			if strings.HasPrefix(program, configProgram) {
				return image
			}
		}
	}

	// All programs now use the enhanced claude-squad image
	return "claudesquad/enhanced:latest"
}

// Start creates and starts a new Docker container, then attaches to it. Program is the command to run in
// the container (ex. claude). workdir is the git worktree directory.
func (d *DockerContainer) Start(workDir string) error {
	ctx := context.Background()

	log.InfoLog.Printf("Starting Docker container: %s with program: %s", d.sanitizedName, d.program)

	// Check if the container already exists
	if d.DoesContainerExist() {
		return fmt.Errorf("docker container already exists: %s", d.sanitizedName)
	}

	// Ensure the Docker image exists (build it if necessary)
	if err := d.ensureImageExists(); err != nil {
		return fmt.Errorf("failed to ensure Docker image exists: %w", err)
	}

	// Prepare mounts
	mounts, err := d.prepareMounts(workDir)
	if err != nil {
		log.ErrorLog.Printf("Warning: Failed to prepare some mounts: %v", err)
	}
	
	// Prepare environment variables
	env := d.prepareEnvironment()

	// Container configuration
	var cmd []string
	// Check if program should use Gemini
	if d.program == ProgramGemini || strings.HasPrefix(d.program, ProgramGemini) {
		cmd = append(cmd, "--gemini")
		// If program has additional arguments, add them
		if strings.Contains(d.program, " ") {
			args := strings.Fields(d.program)
			if len(args) > 1 {
				cmd = append(cmd, args[1:]...)
			}
		}
	} else if strings.Contains(d.program, " ") {
		// For programs with arguments like "claude --some-flag"
		args := strings.Fields(d.program)
		if len(args) > 1 {
			cmd = append(cmd, args[1:]...)
		}
	}
	// If no arguments, cmd will be empty and container will start with default (Claude)
	
	config := &container.Config{
		Image:        d.getDockerImage(),
		Cmd:          cmd,
		WorkingDir:   "/workspace",
		Tty:          true,
		AttachStdin:  true,
		AttachStdout: true,
		AttachStderr: true,
		OpenStdin:    true,
		StdinOnce:    false,
		Env: env,
	}
	
	// Host configuration with enhanced mounts
	hostConfig := &container.HostConfig{
		Mounts: mounts,
		// Auto-remove containers when they stop
		AutoRemove: false,
	}

	// Create the container
	log.InfoLog.Printf("Creating Docker container with name: %s", d.sanitizedName)
	resp, err := d.dockerClient.ContainerCreate(ctx, config, hostConfig, nil, nil, d.sanitizedName)
	if err != nil {
		return fmt.Errorf("error creating docker container: %w", err)
	}
	d.containerID = resp.ID
	log.InfoLog.Printf("Created container with ID: %s", d.containerID)

	// Start the container
	log.InfoLog.Printf("Starting container: %s", d.containerID)
	if err := d.dockerClient.ContainerStart(ctx, d.containerID, container.StartOptions{}); err != nil {
		// Cleanup on failure
		log.ErrorLog.Printf("Failed to start container %s: %v", d.containerID, err)
		if removeErr := d.dockerClient.ContainerRemove(ctx, d.containerID, container.RemoveOptions{Force: true}); removeErr != nil {
			err = fmt.Errorf("%v (cleanup error: %v)", err, removeErr)
		}
		return fmt.Errorf("error starting docker container: %w", err)
	}

	// Wait for container to be running
	timeout := time.After(5 * time.Second)
	for {
		inspect, err := d.dockerClient.ContainerInspect(ctx, d.containerID)
		if err == nil && inspect.State.Running {
			break
		}
		select {
		case <-timeout:
			if cleanupErr := d.Close(); cleanupErr != nil {
				err = fmt.Errorf("%v (cleanup error: %v)", err, cleanupErr)
			}
			return fmt.Errorf("timed out waiting for container %s to start: %v", d.sanitizedName, err)
		default:
			time.Sleep(100 * time.Millisecond)
		}
	}

	log.InfoLog.Printf("Container %s started successfully, restoring state...", d.containerID)
	err = d.Restore()
	if err != nil {
		log.ErrorLog.Printf("Failed to restore container %s: %v", d.containerID, err)
		if cleanupErr := d.Close(); cleanupErr != nil {
			err = fmt.Errorf("%v (cleanup error: %v)", err, cleanupErr)
		}
		return fmt.Errorf("error restoring docker container: %w", err)
	}

	// Handle initial prompts like tmux does
	if d.program == ProgramClaude || strings.HasPrefix(d.program, ProgramAider) || strings.HasPrefix(d.program, ProgramGemini) {
		searchString := "Do you trust the files in this folder?"
		tapFunc := d.TapEnter
		iterations := 5
		if d.program != ProgramClaude {
			searchString = "Open documentation url for more info"
			tapFunc = d.TapDAndEnter
			iterations = 10
		}
		// Deal with "do you trust the files" screen by sending an enter keystroke.
		for i := 0; i < iterations; i++ {
			time.Sleep(200 * time.Millisecond)
			content, err := d.CaptureContainerOutput()
			if err != nil {
				log.ErrorLog.Printf("could not check 'do you trust the files screen': %v", err)
			}
			if strings.Contains(content, searchString) {
				if err := tapFunc(); err != nil {
					log.ErrorLog.Printf("could not tap enter on trust screen: %v", err)
				}
				break
			}
		}
	}
	return nil
}

// Restore attaches to an existing container
func (d *DockerContainer) Restore() error {
	d.monitor = newStatusMonitor()
	return nil
}

type statusMonitor struct {
	// Store hashes to save memory.
	prevOutputHash []byte
}

func newStatusMonitor() *statusMonitor {
	return &statusMonitor{}
}

// hash hashes the string.
func (m *statusMonitor) hash(s string) []byte {
	h := sha256.New()
	h.Write([]byte(s))
	return h.Sum(nil)
}

// TapEnter sends an enter keystroke to the container.
func (d *DockerContainer) TapEnter() error {
	if d.hijackedResponse.Conn != nil {
		_, err := d.hijackedResponse.Conn.Write([]byte{0x0D})
		if err != nil {
			return fmt.Errorf("error sending enter keystroke to container: %w", err)
		}
	}
	return nil
}

// TapDAndEnter sends 'D' followed by an enter keystroke to the container.
func (d *DockerContainer) TapDAndEnter() error {
	if d.hijackedResponse.Conn != nil {
		_, err := d.hijackedResponse.Conn.Write([]byte{0x44, 0x0D})
		if err != nil {
			return fmt.Errorf("error sending D+enter keystroke to container: %w", err)
		}
	}
	return nil
}

func (d *DockerContainer) SendKeys(keys string) error {
	if d.hijackedResponse.Conn != nil {
		_, err := d.hijackedResponse.Conn.Write([]byte(keys))
		return err
	}
	return fmt.Errorf("not attached to container")
}

// HasUpdated checks if the container output has changed since the last tick.
func (d *DockerContainer) HasUpdated() (updated bool, hasPrompt bool) {
	// Check if container is properly initialized
	if d.containerID == "" {
		log.ErrorLog.Printf("HasUpdated called on container with empty ID: %s", d.sanitizedName)
		return false, false
	}
	
	content, err := d.CaptureContainerOutput()
	if err != nil {
		log.ErrorLog.Printf("error capturing container output in status monitor: %v", err)
		return false, false
	}

	// Only set hasPrompt for claude and aider. Use these strings to check for a prompt.
	if d.program == ProgramClaude {
		hasPrompt = strings.Contains(content, "No, and tell Claude what to do differently")
	} else if strings.HasPrefix(d.program, ProgramAider) {
		hasPrompt = strings.Contains(content, "(Y)es/(N)o/(D)on't ask again")
	} else if strings.HasPrefix(d.program, ProgramGemini) {
		hasPrompt = strings.Contains(content, "Yes, allow once")
	}

	if !bytes.Equal(d.monitor.hash(content), d.monitor.prevOutputHash) {
		d.monitor.prevOutputHash = d.monitor.hash(content)
		return true, hasPrompt
	}
	return false, hasPrompt
}

func (d *DockerContainer) Attach() (chan struct{}, error) {
	ctx := context.Background()
	d.attachCh = make(chan struct{})

	d.wg = &sync.WaitGroup{}
	d.wg.Add(1)
	d.ctx, d.cancel = context.WithCancel(context.Background())

	// Attach to the container
	attachOptions := container.AttachOptions{
		Stream: true,
		Stdin:  true,
		Stdout: true,
		Stderr: true,
	}

	hijackedResponse, err := d.dockerClient.ContainerAttach(ctx, d.containerID, attachOptions)
	if err != nil {
		return nil, fmt.Errorf("error attaching to container: %w", err)
	}
	d.hijackedResponse = hijackedResponse

	// Handle stdout/stderr
	go func() {
		defer d.wg.Done()
		_, _ = stdcopy.StdCopy(os.Stdout, os.Stderr, d.hijackedResponse.Reader)
		// When stdcopy returns, it means the connection was closed
		select {
		case <-d.ctx.Done():
			// Normal detach, do nothing
		default:
			// If context is not done, it was likely an abnormal termination
			fmt.Fprintf(os.Stderr, "\n\033[31mError: Container terminated without detaching. Use Ctrl-Q to properly detach from containers.\033[0m\n")
		}
	}()

	// Handle stdin
	go func() {
		// Close the channel after 50ms
		timeoutCh := make(chan struct{})
		go func() {
			time.Sleep(50 * time.Millisecond)
			close(timeoutCh)
		}()

		// Read input from stdin and check for Ctrl+q
		buf := make([]byte, 32)
		for {
			nr, err := os.Stdin.Read(buf)
			if err != nil {
				if err == io.EOF {
					break
				}
				continue
			}

			// Nuke the first bytes of stdin to prevent container from reading control sequences
			select {
			case <-timeoutCh:
			default:
				log.InfoLog.Printf("nuked first stdin: %s", buf[:nr])
				continue
			}

			// Check for Ctrl+q (ASCII 17)
			if nr == 1 && buf[0] == 17 {
				// Detach from the container
				d.Detach()
				return
			}

			// Forward other input to container
			if d.hijackedResponse.Conn != nil {
				_, _ = d.hijackedResponse.Conn.Write(buf[:nr])
			}
		}
	}()

	return d.attachCh, nil
}

// Detach disconnects from the current container.
func (d *DockerContainer) Detach() {
	defer func() {
		close(d.attachCh)
		d.attachCh = nil
		d.cancel = nil
		d.ctx = nil
		d.wg = nil
	}()

	// Close the hijacked connection
	if d.hijackedResponse.Conn != nil {
		err := d.hijackedResponse.CloseWrite()
		if err != nil {
			msg := fmt.Sprintf("error closing container connection: %v", err)
			log.ErrorLog.Println(msg)
		}
		d.hijackedResponse.Close()
		d.hijackedResponse = types.HijackedResponse{}
	}

	// Cancel goroutines created by Attach.
	d.cancel()
	d.wg.Wait()

	// Restore monitor
	if err := d.Restore(); err != nil {
		msg := fmt.Sprintf("error restoring container monitor: %v", err)
		log.ErrorLog.Println(msg)
		panic(msg)
	}
}

// Close terminates the Docker container and cleans up resources
func (d *DockerContainer) Close() error {
	ctx := context.Background()
	var errs []error

	if d.hijackedResponse.Conn != nil {
		d.hijackedResponse.Close()
		d.hijackedResponse = types.HijackedResponse{}
	}

	if d.containerID != "" {
		// Stop the container
		timeout := 10
		if err := d.dockerClient.ContainerStop(ctx, d.containerID, container.StopOptions{Timeout: &timeout}); err != nil {
			errs = append(errs, fmt.Errorf("error stopping docker container: %w", err))
		}

		// Remove the container
		if err := d.dockerClient.ContainerRemove(ctx, d.containerID, container.RemoveOptions{Force: true}); err != nil {
			errs = append(errs, fmt.Errorf("error removing docker container: %w", err))
		}
	}

	if len(errs) == 0 {
		return nil
	}
	if len(errs) == 1 {
		return errs[0]
	}

	errMsg := "multiple errors occurred during cleanup:"
	for _, err := range errs {
		errMsg += "\n  - " + err.Error()
	}
	return errors.New(errMsg)
}

// SetDetachedSize is a no-op for Docker containers as they don't have the same
// window size constraints as tmux
func (d *DockerContainer) SetDetachedSize(width, height int) error {
	// Docker containers handle their own terminal sizing through the TTY
	return nil
}

func (d *DockerContainer) DoesContainerExist() bool {
	ctx := context.Background()
	_, err := d.dockerClient.ContainerInspect(ctx, d.sanitizedName)
	return err == nil
}

// CaptureContainerOutput captures the output of the Docker container
func (d *DockerContainer) CaptureContainerOutput() (string, error) {
	ctx := context.Background()
	
	// Check if container ID is set
	if d.containerID == "" {
		log.ErrorLog.Printf("Container ID is empty for container: %s", d.sanitizedName)
		return "", fmt.Errorf("container ID is empty - container may not have been started properly")
	}
	
	// Log container status for debugging
	log.InfoLog.Printf("Capturing output for container ID: %s (name: %s)", d.containerID, d.sanitizedName)
	
	// Get container logs
	options := container.LogsOptions{
		ShowStdout: true,
		ShowStderr: true,
		Tail:       "100", // Get last 100 lines
	}

	reader, err := d.dockerClient.ContainerLogs(ctx, d.containerID, options)
	if err != nil {
		return "", fmt.Errorf("error getting container logs for ID %s: %w", d.containerID, err)
	}
	defer reader.Close()

	buf := new(bytes.Buffer)
	_, err = stdcopy.StdCopy(buf, buf, reader)
	if err != nil {
		return "", fmt.Errorf("error reading container logs: %w", err)
	}

	return buf.String(), nil
}

// CaptureContainerOutputWithOptions captures the container output with additional options
func (d *DockerContainer) CaptureContainerOutputWithOptions(start, end string) (string, error) {
	// For Docker, we'll just use the standard capture since Docker logs API
	// doesn't have the same line-based options as tmux
	return d.CaptureContainerOutput()
}

// prepareMounts prepares all necessary volume mounts for the container
func (d *DockerContainer) prepareMounts(workDir string) ([]mount.Mount, error) {
	mounts := []mount.Mount{
		{
			Type:   mount.TypeBind,
			Source: workDir,
			Target: "/workspace",
		},
	}

	// Get user home directory
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return mounts, fmt.Errorf("failed to get user home directory: %w", err)
	}

	// Mount .claude directory for authentication and conversation history
	claudeDir := filepath.Join(homeDir, ".claude")
	if _, err := os.Stat(claudeDir); err == nil {
		mounts = append(mounts, mount.Mount{
			Type:   mount.TypeBind,
			Source: claudeDir,
			Target: "/home/claude-user/.claude",
		})
		log.InfoLog.Printf("Mounting Claude directory: %s", claudeDir)
	} else {
		log.InfoLog.Printf("Claude directory not found, skipping mount: %s", claudeDir)
	}

	// Mount .gemini directory for Gemini OAuth credentials (if exists)
	geminiDir := filepath.Join(homeDir, ".gemini")
	if _, err := os.Stat(geminiDir); err == nil {
		mounts = append(mounts, mount.Mount{
			Type:   mount.TypeBind,
			Source: geminiDir,
			Target: "/home/claude-user/.gemini",
		})
		log.InfoLog.Printf("Mounting Gemini directory: %s", geminiDir)
	} else {
		log.InfoLog.Printf("Gemini directory not found, skipping mount: %s", geminiDir)
	}

	// Mount .gitconfig for git user configuration (read-only)
	gitConfigPath := filepath.Join(homeDir, ".gitconfig")
	if _, err := os.Stat(gitConfigPath); err == nil {
		mounts = append(mounts, mount.Mount{
			Type:     mount.TypeBind,
			Source:   gitConfigPath,
			Target:   "/home/claude-user/.gitconfig",
			ReadOnly: true,
		})
		log.InfoLog.Printf("Mounting git config: %s", gitConfigPath)
	} else {
		log.InfoLog.Printf("Git config not found, skipping mount: %s", gitConfigPath)
	}

	// Mount user's MCP servers configuration if it exists
	mcpConfigPath := filepath.Join(homeDir, ".claude-squad", "mcp-servers.txt")
	if _, err := os.Stat(mcpConfigPath); err == nil {
		mounts = append(mounts, mount.Mount{
			Type:     mount.TypeBind,
			Source:   mcpConfigPath,
			Target:   "/home/claude-user/.claude/mcp-servers.txt",
			ReadOnly: true,
		})
		log.InfoLog.Printf("Mounting MCP servers config: %s", mcpConfigPath)
	} else {
		log.InfoLog.Printf("MCP servers config not found, using defaults: %s", mcpConfigPath)
	}

	return mounts, nil
}

// prepareEnvironment prepares environment variables for the container
func (d *DockerContainer) prepareEnvironment() []string {
	env := []string{
		"TERM=xterm-256color",
	}

	// Add GitHub token if available
	if githubToken := os.Getenv("GITHUB_TOKEN"); githubToken != "" {
		env = append(env, "GITHUB_TOKEN="+githubToken)
		log.InfoLog.Printf("GitHub token configured for git authentication")
	}

	// Add Google AI Studio API key if available (fallback for Gemini)
	if apiKey := os.Getenv("GOOGLE_AI_STUDIO_API_KEY"); apiKey != "" {
		env = append(env, "GOOGLE_AI_STUDIO_API_KEY="+apiKey)
		log.InfoLog.Printf("Google AI Studio API key configured")
	}

	// Set AI CLI preference if using Gemini
	if d.program == ProgramGemini || strings.HasPrefix(d.program, ProgramGemini) {
		env = append(env, "AI_CLI_PREFERENCE=gemini")
	}

	return env
}

// CleanupContainers kills all Docker containers that start with the prefix
func CleanupContainers(dockerClient *client.Client) error {
	ctx := context.Background()

	// List all containers
	containers, err := dockerClient.ContainerList(ctx, container.ListOptions{All: true})
	if err != nil {
		return fmt.Errorf("failed to list docker containers: %v", err)
	}

	for _, cont := range containers {
		for _, name := range cont.Names {
			// Container names start with "/" in Docker
			name = strings.TrimPrefix(name, "/")
			if strings.HasPrefix(name, ContainerPrefix) {
				log.InfoLog.Printf("cleaning up container: %s", name)
				
				// Stop the container if running
				if cont.State == "running" {
					timeout := 10
					if err := dockerClient.ContainerStop(ctx, cont.ID, container.StopOptions{Timeout: &timeout}); err != nil {
						log.ErrorLog.Printf("failed to stop container %s: %v", name, err)
					}
				}
				
				// Remove the container
				if err := dockerClient.ContainerRemove(ctx, cont.ID, container.RemoveOptions{Force: true}); err != nil {
					return fmt.Errorf("failed to remove docker container %s: %v", name, err)
				}
			}
		}
	}
	return nil
}