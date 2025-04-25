# VMWare Manager

`VMWare Manager.ps1` is a PowerShell menu script designed to manage your VMWare ESXi servers.  It is intended for smaller environments - it does not use vCenter.

<img src=https://raw.githubusercontent.com/ITAutomator/Assets/main/VMware/VMwareManagerMain.png alt="screenshot" width="500"/>

User guide: Click [here](https://github.com/ITAutomator/VMWareManager)  
Download from GitHub as [ZIP](https://github.com/ITAutomator/VMWareManager/archive/refs/heads/main.zip)  
Or Go to GitHub [here](https://github.com/ITAutomator/VMWareManager) and click `Code` (the green button) `> Download Zip`  

## Features

- Retrieve a CSV report of ESXi servers, their VMs and settings.
- Add additional administrators to your ESXi servers.

## Prerequisites

Before using the script, ensure the following:

1. **Powershell Module**: The program will prompt you to install the VMware PowerShell module.  Open a powershell admin prompt and enter: Install-Module -Name VMware.PowerCLI -Scope AllUsers [VMware PowerCLI Docs](https://developer.broadcom.com/powercli)
2. **Esxi Servers to Inventory.csv**: A list of your servers.  A starter file will be created if needed.

## Installation

1. Clone or download this repository.
2. Place the `VMWare Manager` folder in a directory of your choice.

## Usage

1. Double-click `VMWare Manager.cmd` or run the `VMWare Manager.ps1` in PowerShell.
2. On the menu choose R generate a Report CSV file.
3. Use that CSV file to plan updates to your SSIDs.
4. On the menu choose A to add more admins to your servers.

Notes:  
The script is careful about making changes, so that it can be run repeatedly, skipping items that are already OK.  

## Menu: Report

Use the Report menu to export a CSV report of your servers.  

## Menu: Add Admin

Adds an additional User (with password) as Administrator role to your servers.
If the user already exists, the password is not touched but the user is added to the Administrator role.
If everything is already OK, it is simply reported as such.

More info here: [www.itautomator.com](https://www.itautomator.com/vmware-manager/)