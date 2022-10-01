
### Monero GUI Installer

The steps to create the Monero GUI installer in a deterministic method are described below.

First, a [pull request](https://github.com/monero-project/monero-gui/pull/4042) is made to create the new release binaries 

Once this PR is merged, it triggers the Github action which creates them [here](https://github.com/monero-project/monero-gui/actions/runs/3147123066) (take note of the run id number at the end of the URL - this script requires it)

We download the `docker-windows-static` file, then obtain a copy of Monero's 64bit binaries for windows (created by the Gitian build process, hashes of which can be found [here](https://github.com/monero-project/gitian.sigs)).

After placing all the files correcly and touching them so they have the same modification time as the `monero-wallet-gui.exe` from the `docker-windows-static` zip file, InnoSetup creates the .exe file.

This Repo provides a Github actions file , and also a shell script we can run at home on our ubuntu 20.04 machine (yes, i'll create a docker at some point) which ensures that no 'funny business' is happening on Githubs end.

After running the actions script, you will be presented with the [hash](https://github.com/plowsof/monero-gui-exe/actions/runs/3162064376/jobs/5148317773#step:5:15) and the installer is uploaded for download at the end. [Seen here in this build of v18.1.2](https://github.com/plowsof/monero-gui-exe/actions/runs/3162064376)

The official Monero GUI installer file is created on a windows machine, but we are able to replicate the final hash using Linux and W.I.N.E

To use the `make_exe.sh` script at home, ensure you have an ubuntu with wine / jq / curl installed. The only way to cause a differing hash would be if i've failed to account for system timezone offsets ( hopefully not one of those 'it works on my machine' moments ) Test and let me know!
