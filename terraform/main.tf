# Digital Ocean provider configuration
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0.0"
}

# Configure the Digital Ocean Provider
provider "digitalocean" {
  token = var.do_token
}

# Create a new Digital Ocean project
resource "digitalocean_project" "project" {
  name        = var.project_name
  description = "${var.project_name} project created with Terraform"
  purpose     = "Web Application"
  environment = "Development"
  
  # Resources will be added to the project
  resources = [
    digitalocean_droplet.qa_dotca.urn
  ]
}

# Create a new Droplet for QA environment
resource "digitalocean_droplet" "qa_dotca" {
  image    = "docker-20-04"  # Docker-ready Ubuntu image
  name     = "${var.project_name}-qa"
  region   = var.region
  size     = "s-1vcpu-1gb"   # Small droplet with 1 CPU, 1GB RAM
  ssh_keys = [var.ssh_key_fingerprint]
  tags     = ["qa", "nextjs", var.project_name]

  # Script to set up the droplet for running the Next.js container
  user_data = <<-EOF
    #!/bin/bash
    # Update system
    apt-get update
    apt-get upgrade -y
    
    # Install git
    apt-get install -y git

    # Create directory for the app
    mkdir -p /app
    
    # Clone the repository
    git clone ${var.git_repo_url} /app/repo
    cd /app/repo
    git checkout ${var.git_branch}
    
    # Create a deploy script to build and run the Docker container
    cat > /app/deploy.sh <<'SCRIPT'
    #!/bin/bash
    cd /app/repo
    
    # Get the public IP address
    PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
    
    # Pull latest changes
    git pull origin ${var.git_branch}
    
    # Build the Docker image locally
    docker build \
      --build-arg NODE_ENV=production \
      --build-arg NEXT_PUBLIC_API_URL=http://$PUBLIC_IP/api \
      --build-arg NEXT_PUBLIC_ENVIRONMENT=qa \
      -t dotca_qa:latest .
    
    # Stop and remove any existing container
    docker stop dotca_qa || true
    docker rm dotca_qa || true
    
    # Run the new container
    docker run -d \
      --name dotca_qa \
      -p 80:3000 \
      -e NODE_ENV=production \
      -e NEXT_PUBLIC_API_URL=http://$PUBLIC_IP/api \
      -e NEXT_PUBLIC_ENVIRONMENT=qa \
      dotca_qa:latest
    SCRIPT

    # Make the script executable
    chmod +x /app/deploy.sh

    # Run the deploy script
    /app/deploy.sh
  EOF
}

# Create a firewall
resource "digitalocean_firewall" "qa_firewall" {
  name = "${var.project_name}-qa-firewall"
  # Allow SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = length(var.allowed_ssh_ips) > 0 ? var.allowed_ssh_ips : ["0.0.0.0/0", "::/0"]
  }

  # Allow HTTP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow HTTPS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Apply the firewall to the droplet
  droplet_ids = [digitalocean_droplet.qa_dotca.id]
}
