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
		// ---------- Most Modified Files ----------
		fileChanges := make(map[string]int)

		iter, err = repo.Log(&git.LogOptions{From: ref.Hash()})
		if err != nil {
			fmt.Println("❌ Failed to read commits:", err)
			return
		}

		err = iter.ForEach(func(c *object.Commit) error {
			if c.NumParents() == 0 {
				// Skip initial commit with no parent
				return nil
			}

			parent, err := c.Parent(0)
			if err != nil {
				return err
			}

			patch, err := parent.Patch(c)
			if err != nil {
				return err
			}

			for _, stat := range patch.Stats() {
				fileChanges[stat.Name]++
			}
			return nil
		})
		if err != nil {
			fmt.Println("❌ Error while collecting file stats:", err)
			return
		}

		// Sort files by most changes
		type fileStat struct {
			Name  string
			Count int
		}
		var files []fileStat
		for k, v := range fileChanges {
			files = append(files, fileStat{Name: k, Count: v})
		}
		sort.Slice(files, func(i, j int) bool {
			return files[i].Count > files[j].Count
		})

		// Print top 10 modified files
		fmt.Println("\n📁 Most Modified Files")
		fmt.Println("----------------------------")
		for i, f := range files {
			if i >= 10 {
				break
			}
			fmt.Printf("%s: %d changes\n", f.Name, f.Count)
		}

	},
}

func init() {
	rootCmd.AddCommand(statsCmd)

	// Add --path flag
	statsCmd.Flags().StringVarP(&repoPath, "path", "p", "", "Path to local git repo")
}
