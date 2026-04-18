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

func promptCreds() {
	token = promptInput("user token: ")
	guildID = promptInput("guild id: ")
	channelID = promptInput("channel id: ")
	saveEnv(token, guildID, channelID)
}

func saveEnv(t, g, c string) {
	content := fmt.Sprintf("TOKEN=%s\nGUILD_ID=%s\nCHANNEL_ID=%s\n", t, g, c)
	if err := os.WriteFile(".env", []byte(content), 0644); err != nil {
		fmt.Println("failed to write .env:", err)
		os.Exit(1)
	}
}

func loadEnv() bool {
	_ = godotenv.Load()
	token = os.Getenv("TOKEN")
	guildID = os.Getenv("GUILD_ID")
	channelID = os.Getenv("CHANNEL_ID")
	return token != "" && guildID != "" && channelID != ""
}

func tryConnect() bool {
	if client != nil {
		client.Close()
	}
	client = discoself.NewClient(token, &types.DefaultConfig)

	connected := make(chan bool, 1)
	client.AddHandler(types.GatewayEventReady, func(e *types.ReadyEventData) {
		fmt.Printf("logged in as: %s\n", e.User.Username)
		connected <- true
		go runBumpLoop()
	})

	if err := client.Connect(); err != nil {
		fmt.Println("connection error:", err)
		connected <- false
	}

	select {
	case ok := <-connected:
		return ok
	case <-time.After(10 * time.Second):
		fmt.Println("connection timed out.")
		return false
	}
}

func main() {
	if !loadEnv() {
		fmt.Println("no credentials found. please enter your details:")
		promptCreds()
	}

	for {
		if tryConnect() {
			break
		}
		fmt.Println("credentials incorrect. please re-enter:")
		promptCreds()
		loadEnv()
	}

	fmt.Println("running. press ctrl-c to exit.")
	sc := make(chan os.Signal, 1)
	signal.Notify(sc, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	<-sc

	fmt.Println("shutting down...")
	close(stopChan)
	client.Close()
}

func runBumpLoop() {
	for {
		select {
		case <-stopChan:
			fmt.Println("stopping bump loop...")
			return
		default:
			sendBump()

			min := 2 * time.Hour
			maxExtra := 30 * time.Minute
			r := rand.New(rand.NewSource(time.Now().UnixNano()))
			delay := min + time.Duration(r.Int63n(int64(maxExtra)))
			fmt.Printf("next bump in: %s\n", formatDuration(delay))

			select {
			case <-time.After(delay):
			case <-stopChan:
				return
			}
		}
	}
}

func sendBump() {
	cmds, err := discord.GetSlashCommands(client.Gateway, guildID)
	if err != nil {
		fmt.Printf("[%s] no internet connection, will retry next bump\n", time.Now().Format("2006-01-02 15:04:05"))
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

	fmt.Println("disboard bump command not found. is disboard in this server?")
}

func formatDuration(d time.Duration) string {
	h := d / time.Hour
	d -= h * time.Hour
	m := d / time.Minute
	d -= m * time.Minute
	s := d / time.Second
	return fmt.Sprintf("%dh %dm %ds", h, m, s)
}
