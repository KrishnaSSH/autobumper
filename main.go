package main

import (
	"bufio"
	"fmt"
	"math/rand"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/joho/godotenv"
	"github.com/krishnassh/discoself"
	"github.com/krishnassh/discoself/discord"
	"github.com/krishnassh/discoself/types"
)

const disboardAppID = "302050872383242240"

var (
	token     string
	guildID   string
	channelID string
	client    *discoself.Client
	stopChan  = make(chan struct{})
)

func fileExists(name string) bool {
	_, err := os.Stat(name)
	return err == nil
}

func openTTY() (*os.File, error) {
	if f, err := os.Open("CONIN$"); err == nil {
		return f, nil
	}
	return os.Open("/dev/tty")
}

func promptInput(label string) string {
	fmt.Print(label)
	tty, err := openTTY()
	if err != nil {
		reader := bufio.NewReader(os.Stdin)
		input, _ := reader.ReadString('\n')
		return strings.TrimSpace(input)
	}
	defer tty.Close()
	reader := bufio.NewReader(tty)
	input, _ := reader.ReadString('\n')
	return strings.TrimSpace(input)
}

func createEnvFile() {
	fmt.Println(".env not found. Please enter required values:")

	t := promptInput("USER_TOKEN: ")
	g := promptInput("GUILD_ID: ")
	c := promptInput("CHANNEL_ID: ")

	saveEnv(t, g, c)
}

func saveEnv(t, g, c string) {
	content := fmt.Sprintf(
		"TOKEN=%s\nGUILD_ID=%s\nCHANNEL_ID=%s\n",
		t, g, c,
	)

	if err := os.WriteFile(".env", []byte(content), 0644); err != nil {
		fmt.Println("Failed to write .env:", err)
		os.Exit(1)
	}

	fmt.Println(".env updated successfully.")
}

func loadConfig() {
	_ = godotenv.Load()

	token = os.Getenv("TOKEN")
	guildID = os.Getenv("GUILD_ID")
	channelID = os.Getenv("CHANNEL_ID")

	missing := token == "" || guildID == "" || channelID == ""

	if !fileExists(".env") || missing {
		fmt.Println("Enter the following values to create .env file:")

		// reuse existing values if partially present
		if token == "" {
			token = promptInput("USER_TOKEN: ")
		}
		if guildID == "" {
			guildID = promptInput("GUILD_ID: ")
		}
		if channelID == "" {
			channelID = promptInput("CHANNEL_ID: ")
		}

		saveEnv(token, guildID, channelID)
	}
}

func main() {
	loadConfig()

	client = discoself.NewClient(token, &types.DefaultConfig)
	client.AddHandler(types.GatewayEventReady, onReady)

	if err := client.Connect(); err != nil {
		fmt.Println("Error connecting:", err)
		return
	}

	fmt.Println("Running. press ctrl-c to exit.")

	sc := make(chan os.Signal, 1)
	signal.Notify(sc, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	<-sc

	fmt.Println("\nShutting down...")
	close(stopChan)

	client.Close()
}

func onReady(e *types.ReadyEventData) {
	fmt.Printf("Logged in as: %s\n", e.User.Username)

	go func() {
		for {
			select {
			case <-stopChan:
				fmt.Println("Stopping bump loop...")
				return
			default:
				sendBump()

				min := 2 * time.Hour
				maxExtra := 30 * time.Minute

				r := rand.New(rand.NewSource(time.Now().UnixNano()))
				delay := min + time.Duration(r.Int63n(int64(maxExtra)))

				fmt.Printf("Next bump in: %s\n", formatDuration(delay))

				select {
				case <-time.After(delay):
				case <-stopChan:
					return
				}
			}
		}
	}()
}

func sendBump() {
	cmds, err := discord.GetSlashCommands(client.Gateway, guildID)
	if err != nil {
		fmt.Println("Error fetching slash commands:", err)
		return
	}

	for _, cmd := range cmds.ApplicationCommand {
		if cmd.Name == "bump" && cmd.ApplicationID == disboardAppID {
			if client.SendSlashCommand(channelID, guildID, cmd) {
				fmt.Printf("[%s] /bump sent successfully\n", time.Now().Format("2006-01-02 15:04:05"))
			} else {
				fmt.Printf("[%s] /bump failed\n", time.Now().Format("2006-01-02 15:04:05"))
			}
			return
		}
	}

	fmt.Println("Disboard bump command not found. Is Disboard in this server?")
}

func formatDuration(d time.Duration) string {
	h := d / time.Hour
	d -= h * time.Hour

	m := d / time.Minute
	d -= m * time.Minute

	s := d / time.Second

	return fmt.Sprintf("%d hours %d minutes %d seconds", h, m, s)
}
