# arr-stack

[![Last Commit](https://img.shields.io/github/last-commit/SighItHappens/arr-stack)](https://github.comSighItHappens/arr-stack/commits/main) [![Open Issues](https://img.shields.io/github/issues/SighItHappens/arr-stack)](https://github.com/SighItHappens/arr-stack/issues)

## Description

`arr-stack` provides a streamlined way to deploy a comprehensive suite of media management applications (Lidarr, Overseerr, Prowlarr, Radarr, Readarr, Recyclarr, and Sonarr) alongside Deluge as the torrent client, all securely tunneled through Proton VPN. This project utilizes Docker Compose to orchestrate the setup of these interconnected services, making it easy to get your media server up and running with enhanced privacy and automation.

## Table of Contents

* [Description](#description)
* [Features](#features)
* [Technologies Used](#technologies-used)
* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Configuration](#configuration)
* [Usage](#usage)
* [Contributing](#contributing)
* [License](#license)
* [Disclaimer](#disclaimer)

## Features

* **Comprehensive "arr" Suite:** Easily deploy Lidarr, Overseerr, Prowlarr, Radarr, Readarr, Recyclarr, and Sonarr.
* **Deluge Integration:** Includes Deluge as the torrent downloader.
* **Proton VPN Protection:** All traffic from Deluge is routed through a Proton VPN container for enhanced privacy.
* **Docker Compose:** Simple and consistent deployment using Docker Compose.
* **Environment Variable Configuration:** Utilizes `.env` files for easy configuration of sensitive information.
* **Easy Setup:** Get your media server running quickly with minimal configuration.
* **Isolated Services:** Each application runs in its own container, ensuring isolation and easier management.

## Technologies Used

* Docker
* Docker Compose
* Lidarr
* Overseerr
* Prowlarr
* Radarr
* Readarr
* Recyclarr
* Sonarr
* Deluge
* Proton VPN (OpenVPN configuration within a Docker container)

## Prerequisites

* **Docker:** Make sure you have Docker installed on your system. You can find installation instructions for your platform here: [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)
* **Docker Compose:** Ensure you have Docker Compose installed. It usually comes bundled with Docker Desktop, or you can install it separately: [https://docs.docker.com/compose/install/](https://docs.docker.com/compose/install/)
* **Proton VPN Account:** You will need a Proton VPN account with access to OpenVPN configuration files.
* **Proton VPN OpenVPN Configuration:** You'll need to download the OpenVPN configuration files (`.ovpn`) and place them in the `arr-stack/protonvpn` directory.

## Installation
 - **Clone the repository:**

    ```bash
    git clone [repository URL]
    cd arr-stack
    ```

 - **Configure Settings:**

    * Create a file named `.env` in the `arr-stack` directory.
    * Add the following environment variables to this file with your specific values:

        ```
        VPN_USER=your_protonvpn_username
        VPN_PASS=your_protonvpn_password
        LAN_NETWORK=your_local_network_subnet_e.g._192.168.1.0/24
        HOME_DIR=/path/to/your/home/directory # e.g., /home/user or /Users/user
        ```

        * **`VPN_USER`:** Your Proton VPN username.
        * **`VPN_PASS`:** Your Proton VPN password.
        * **`LAN_NETWORK`:** Your local network subnet in CIDR notation (e.g., 192.168.1.0/24). This might be needed for certain network configurations within the containers.
        * **`HOME_DIR`:** The absolute path to your home directory on the host machine (e.g., /home/user or /Users/user). This might be used for volume mappings or other configurations.
    * Ensure this file has appropriate permissions to prevent unauthorized access (e.g., `chmod 600 .env`).

 - **Configure Monitoring API Keys and Passwords:**

    * Create a file named `.env` in the `arr-stack/monitoring` directory.
    * Add the API keys and passwords for your "arr" applications, Deluge, and Pi-hole (if you are using it) to this file:

        ```
        SONARR_API_KEY=your_sonarr_api_key
        RADARR_API_KEY=your_radarr_api_key
        LIDARR_API_KEY=your_lidarr_api_key
        PROWLARR_API_KEY=your_prowlarr_api_key
        READARR_API_KEY=your_readarr_api_key
        DELUGE_PASS=your_deluge_web_ui_password
        PIHOLE_PASS=your_pihole_api_password # Optional, if you are monitoring Pi-hole
        ```

        * You will typically find the API keys in the settings of each "arr" application.
        * `DELUGE_PASS` is the password you use to access the Deluge web UI.
        * `PIHOLE_PASS` is your Pi-hole API password (if you intend to use the monitoring features for Pi-hole).
    * Ensure this file has appropriate permissions to prevent unauthorized access (e.g., `chmod 600 .env`).

 - **Place Proton VPN `.ovpn` file(s):**

    * Download your desired Proton VPN OpenVPN configuration file(s) (e.g., `us-il#17.protonvpn.net.udp.ovpn`) and place them in the `${HOME_DIR}/deluge/config/openvpn` directory. You can rename them to be more descriptive if needed.

## Configuration

The primary configuration is now handled through the `.env` files in the `arr-stack` and `monitoring` directories.

## Usage

 - Start the stack:
```
docker-compose up -d
```

Docker Compose will automatically load the environment variables from the .env files.

 - **Access the web interfaces:**
    * Sonarr: `http://your_server_ip:8989`
    * Radarr: `http://your_server_ip:7878`
    * Lidarr: `http://your_server_ip:8686`
    * Readarr: `http://your_server_ip:8787`
    * Overseerr: `http://your_server_ip:5055`
    * Prowlarr: `http://your_server_ip:9696`
    * Deluge Web UI: `http://your_server_ip:8112`
    * Recyclarr: Recyclarr is typically configured via YAML files and run as a scheduled task or manually. It doesn't usually have a web UI. Refer to the Recyclarr documentation for its usage.
    * Monitoring (if included): Check the docker-compose.yml in the monitoring directory for the exposed port of any monitoring tools (e.g., Grafana, Prometheus).
    
 - **Configure the "arr" applications:**
    
   Once the services are running, you can access their web interfaces to configure them according to your preferences, including connecting to Prowlarr for indexers and Deluge as the download client.
 - **Monitor logs:**
 
   To check the status of the containers or troubleshoot issues, you can view the logs:
   ```
   docker-compose logs -f [service_name]
   ```

    Replace [service_name] with the name of the container you want to inspect (e.g., sonarr, deluge, protonvpn, overseerr).
    
 - **Stop the stack:**
   ```
   docker-compose down
   ```

## Contributing
Contributions are welcome! If you find any issues or have suggestions for improvements, please feel free to:
 - Open an issue: Report bugs, suggest new features, or ask questions.
 - Submit a pull request: Fork the repository, make your changes, and submit a pull request. 
 
## License

[Specify your project's license here. If you have a LICENSE file, you can refer to it.]

Example: This project is licensed under the MIT License.

## Disclaimer
This project is provided as-is without any warranty. Using a VPN does not guarantee complete anonymity or security. It is your responsibility to understand and comply with all applicable laws and terms of service. Ensure your Proton VPN configuration is correct and that you understand the implications of routing your traffic through a VPN.