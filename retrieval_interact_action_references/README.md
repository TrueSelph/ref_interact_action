# Retrieval Interact Action References

![GitHub release (latest by date)](https://img.shields.io/github/v/release/TrueSelph/retrieval_interact_action_references)
![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/TrueSelph/retrieval_interact_action_references/test-action.yaml)
![GitHub issues](https://img.shields.io/github/issues/TrueSelph/retrieval_interact_action_references)
![GitHub pull requests](https://img.shields.io/github/issues-pr/TrueSelph/retrieval_interact_action_references)
![GitHub](https://img.shields.io/github/license/TrueSelph/retrieval_interact_action_references)

JIVAS action that adds references for the context that was used to generate the response.

## Package Information

- **Name:** `jivas/retrieval_interact_action_references`
- **Author:** [V75 Inc.](https://v75inc.com/)
- **Architype:** `RetrievalInteractActionReferences`
- **Version:** `0.0.1`

## Meta Information

- **Title:** Retrieval Interact Action References
- **Description:** This action adds references to the context that was used to generate the response.
- **Group:** core
- **Type:** interact_action

## Configuration

- **Singleton:** false
- **Order:**
  - **Weight:** 0
  - **After:** `jivas/persona_interact_action`
  - **Before:** `jivas/phoneme_interact_action`

## Dependencies

- **Jivas:** `^2.0.0`
- **Actions:**
  - `jivas/persona_interact_action`: `~0.0.1`


This package is designed to add references to the context that was used to generate the response. It is a core interact action, configured as a singleton. The package requires the Jivas library version 2.0.0 and includes specific action dependencies such as `persona_interact_action`.

---

## How to Use

Enable metadata for your retrieval interact action and add this action after persona_interact_action.


### Best Practices
- Ensure the retrieval interact action reference is properly configured and accessible.
- Test pipelines in a staging environment before production use.

---

## 🔰 Contributing

- **🐛 [Report Issues](https://github.com/TrueSelph/retrieval_interact_action_references/issues)**: Submit bugs found or log feature requests for the `retrieval_interact_action_references` project.
- **💡 [Submit Pull Requests](https://github.com/TrueSelph/retrieval_interact_action_references/blob/main/CONTRIBUTING.md)**: Review open PRs, and submit your own PRs.

<details closed>
<summary>Contributing Guidelines</summary>

1. **Fork the Repository**: Start by forking the project repository to your GitHub account.
2. **Clone Locally**: Clone the forked repository to your local machine using a git client.
   ```sh
   git clone https://github.com/TrueSelph/retrieval_interact_action_references
   ```
3. **Create a New Branch**: Always work on a new branch, giving it a descriptive name.
   ```sh
   git checkout -b new-feature-x
   ```
4. **Make Your Changes**: Develop and test your changes locally.
5. **Commit Your Changes**: Commit with a clear message describing your updates.
   ```sh
   git commit -m 'Implemented new feature x.'
   ```
6. **Push to GitHub**: Push the changes to your forked repository.
   ```sh
   git push origin new-feature-x
   ```
7. **Submit a Pull Request**: Create a PR against the original project repository. Clearly describe the changes and their motivations.
8. **Review**: Once your PR is reviewed and approved, it will be merged into the main branch. Congratulations on your contribution!
</details>

<details open>
<summary>Contributor Graph</summary>
<br>
<p align="left">
    <a href="https://github.com/TrueSelph/retrieval_interact_action_references/graphs/contributors">
        <img src="https://contrib.rocks/image?repo=TrueSelph/retrieval_interact_action_references" />
   </a>
</p>
</details>

## 🎗 License

This project is protected under the Apache License 2.0. See [LICENSE](../LICENSE) for more information.
