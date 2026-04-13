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

func promptInput(label string) string {
	reader := bufio.NewReader(os.Stdin)
	fmt.Print(label)
	input, _ := reader.ReadString('\n')
	return strings.TrimSpace(input)
}

func createEnvFile() {
	fmt.Println(".env not found. Please enter required values:")

	t := promptInput("USER_TOKEN: ")
	g := promptInput("GUILD_ID: ")
	c := promptInput("CHANNEL_ID: ")

	content := fmt.Sprintf(
		"TOKEN=%s\nGUILD_ID=%s\nCHANNEL_ID=%s\n",
		t, g, c,
	)

	if err := os.WriteFile(".env", []byte(content), 0644); err != nil {
		fmt.Println("Failed to write .env:", err)
		os.Exit(1)
	}

	fmt.Println(".env file created successfully.")
}

func loadConfig() {
	if !fileExists(".env") {
		createEnvFile()
	}

	_ = godotenv.Load()

	token = os.Getenv("TOKEN")
	guildID = os.Getenv("GUILD_ID")
	channelID = os.Getenv("CHANNEL_ID")

	if token == "" || guildID == "" || channelID == "" {
		fmt.Println("Invalid .env. Missing TOKEN, GUILD_ID, or CHANNEL_ID")
		os.Exit(1)
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
					fmt.Println("Interrupted during wait")
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
