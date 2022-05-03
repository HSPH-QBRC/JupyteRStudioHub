### Terraform-based JupyterLab + RStudio setup

This repository contains files and helper scripts which will setup a server with both JupyterHub and RStudio on a GCP VM.

#### Instructions
1. Install [git](https://git-scm.com), [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) and [Terraform](https://www.terraform.io/downloads.html)
2. Clone this repository
3. Create a service account key file using the GCP console or via command line. This service account file should have privileges to create networks and VMs. The easiest is probably to assign it "editor" privileges. Download the resulting JSON-format file to your cloned directory.
    - To do this via commandline, run: 
```
gcloud iam service-accounts create <NAME> --display-name="<SOME NAME>"
gcloud projects add-iam-policy-binding <GCP project name> \ 
    --member='serviceAccount:<NAME>@<GCP project name>.iam.gserviceaccount.com' \ 
    --role='roles/editor'
gcloud iam service-accounts keys create key.json --iam-account=<NAME>@<GCP project name>.iam.gserviceaccount.com
```
where `<NAME>` is the name of your service account (which has some regex-based restrictions, so keep it simple) and `<GCP project name>` is the *name* of your GCP project (not the numerical ID).

Running those commands will download a file named `key.json` to your current working directory. BE CAREFUL WITH THAT KEY!! The `.gitignore` will ignore "*.json" files, which is hopefully enough of a barrier to prevent accidental commits.

4. Copy the terraform variable template file: `cp terraform.tfvars.tmpl terraform.tfvars` and fill-in the variables. The `credentials_file` variable is the name of the JSON-format service account key file you just created/downloaded. See the section below which explains the variables in more detail.
5. `terraform init`
6. `terraform apply`

This will create the VM and report the IP address to your terminal. 

Once the installation scripts are complete, you should be able to access a RStudio instance at `https://<DOMAIN>/rstudio/` and a JupyterLab instance at `https://<DOMAIN>/jupyter/`. The VM has nginx as a proxy server which performs automatic https redirects.

Note that visting that address will prompt for a login. As set up, both JupyterLab and RStudio permit the username/password of user accounts on the VM itself. To create those, see the section below on creating users.

#### Terraform variables

This section explains the required terraform variables in further detail.

- `project_id`: The name of the Google Cloud project (not the numeric ID)
- `credentials_file`: The path to the GCP JSON-format credentials file created in the initial steps above.
- `jupyterstudio_machine_config`: The machine specs for the virtual machine.
    - `machine_type`: A GCP-compatiable machine specification, e.g. "e2-standard-2" which dictates the number of virtual processors and RAM
    - `disk_size_gb`: An integer giving the disk size in GB
- `domain`: The domain of the site you want to deploy to.
- `managed_dns_zone`: This script assumes you have your domain registered and managed by GCP's DNS. Each site has its own managed zone where you can add DNS records. We need this since we create an A record which maps your domain to the new VM created.
- `admin_email`: The certbot SSL certificate process needs an admin email to work. 

Note that this script was created under the premise that the site would be deployed with a "friendly" domain name instead of pointing directly at the public IP address of the GCP VM. Certainly those modifications are possible, but we have not tested that here.

#### Creating users

The repository also comes with a helper script (`add_users.sh`). This allows us to add new system users (which effectively creates a login for both JupyterLab and RStudio) and to copy any common files that might need to be shared with all users (e.g. example data files). The script assumes the data is located in `/home/common_data`. If there is no common data to share, then the copy commands will just fail.

To run the script, you first have to SSH to the machine. Then, create a basic text file where each line has 3 elements delimited by a comma:
- email address
- a username (needs to be Unix valid!)
- a plain text password

Be careful not to put spaces in there, as it's a pretty brittle script. e.g. the file should look like:

```
foo@email.com,foo-user,abc123
bar@email.com,someone-else,def456
```

The `add_users.sh` takes this file as its first and only argument. It then iterates through each line, creating users, home directories, and copying any files.

The usernames and passwords in that file can then be used to log into JupyterLab or RStudio. Each user will have their own workspace with copies of the necessary files.