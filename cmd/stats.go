package cmd

import (
	"fmt"
	"path/filepath"
	"sort"

	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing/object"
	"github.com/spf13/cobra"
)

var repoPath string

var statsCmd = &cobra.Command{
	Use:   "stats",
	Short: "Show Git repo stats",
	Long:  `Analyze a Git repository and show useful insights like contributors and commits.`,
	Run: func(cmd *cobra.Command, args []string) {
		if repoPath == "" {
			fmt.Println("❌ Please provide a repo path using --path flag")
			return
		}

		absPath, _ := filepath.Abs(repoPath)
		repo, err := git.PlainOpen(absPath)
		if err != nil {
			fmt.Println("❌ Failed to open repo:", err)
			return
		}

		ref, err := repo.Head()
		if err != nil {
			fmt.Println("❌ Failed to get HEAD:", err)
			return
		}

		iter, err := repo.Log(&git.LogOptions{From: ref.Hash()})
		if err != nil {
			fmt.Println("❌ Failed to read commits:", err)
			return
		}

		contributorMap := make(map[string]int)

		err = iter.ForEach(func(c *object.Commit) error {
			contributorMap[c.Author.Name]++
			return nil
		})
		if err != nil {
			fmt.Println("❌ Failed to iterate commits:", err)
			return
		}

		// Sort contributors by commits
		type contributor struct {
			Name    string
			Commits int
		}
		var list []contributor
		for k, v := range contributorMap {
			list = append(list, contributor{Name: k, Commits: v})
		}
		sort.Slice(list, func(i, j int) bool {
			return list[i].Commits > list[j].Commits
		})

		// Print results
		fmt.Println("📊 Top Contributors")
		fmt.Println("--------------------")
		for _, c := range list {
			fmt.Printf("%s: %d commits\n", c.Name, c.Commits)
		}
	},
}

func init() {
	rootCmd.AddCommand(statsCmd)

	// Add --path flag
	statsCmd.Flags().StringVarP(&repoPath, "path", "p", "", "Path to local git repo")
}
