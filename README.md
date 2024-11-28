This is the link to the git repository: https://github.com/wlabedz/learn-terraform-github-actions

Why do we need Terraform Cloud (or another backend) when we use CI/CD?

The first advantage of using Terraform Cloud is storing the information about the state of the infrastructure. While not using any backend Terraform needs to maintain this information in a state file and store it locally on the machine running commands, whereas while using backend the file is stored remotely, what 
Moreover having backend allows better work organization within a team as everybody works with the same state and configuration. In addition it allows users to run Terraform commands on remote infrastructure, which also helps avoid storing some sensitive credentials locally as they are stored in backend environment variables.