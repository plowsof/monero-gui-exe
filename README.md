
### Monero GUI Installer

The steps to create the Monero GUI installer in a deterministic way are described below.

First, a [pull request](https://github.com/monero-project/monero-gui/pull/4042) is made to create the new release binaries 

Once this PR is merged, it triggers the Github action which creates them [here](https://github.com/monero-project/monero-gui/actions/runs/3147123066) (take note of the run id number at the end of the URL - this script requires it)

We download the `docker-windows-static` file, then obtain a copy of Monero's 64bit binaries for windows, from getmonero.org (created by the Gitian build process, hashes of which can be found [here](https://github.com/monero-project/gitian.sigs)).

After placing all the files correcly and touching them so they have the same modification time as the `monero-wallet-gui.exe` from the `docker-windows-static` zip file, InnoSetup creates the .exe file.

This Repo provides a Github actions file , and also a shell script we can run at home on our ubuntu 20.04 machine (yes, i'll create a docker at some point) which ensures that no 'funny business' is happening on Githubs end.

After running the actions script, you will be presented with the [hash](https://github.com/plowsof/monero-gui-exe/actions/runs/3162064376/jobs/5148317773#step:5:15) and the installer is uploaded at the end. [Seen here in this build of v18.1.2](https://github.com/plowsof/monero-gui-exe/actions/runs/3162064376)

The official Monero GUI installer file is created on a windows machine, but we are able to replicate the final hash using Linux and W.I.N.E

To use the `make_exe.sh` script at home, ensure you have an ubuntu with wine / jq / curl / git installed. (pass the runid and a github token with public repo access)
```
./make_exe.sh 3147123066 ghp_hunter2U*U*u8888**888
```

Or, you can just fork this repo, and run the actions file      
![Screenshot from 2022-10-01 01-15-55](https://user-images.githubusercontent.com/77655812/193374469-2ca675f0-fd43-4462-81de-5b753b8893db.png)

## Docker
Clone this repository:
```
git clone https://github.com/plowsof/monero-gui-exe
```
```
cd monero-gui-exe
```
Note: The container is not optimised and its about 3GB
```
docker build -t gui .
```
Once built you need to run the container and pass it 2 arguments.
1st - runid
2nd - a github token with access to public repositories
```
docker run -it gui 3147123066 ghp_hunter2U*U*u8888**888
```
At the end you should see something like:
```
Hash of gitian built cli zip:
0a3d4d1af7e094c05352c31b2dafcc6ccbc80edc195ca9eaedc919c36accd05a  monero-win-x64-v0.18.1.2.zip
# ---------------------
# Monero GUI installer hash:
# c5dbf3e8fca7341dea1194e57b22f233ceb9471aca8692da6ffd0b4bc3a54a1b
# ---------------------
```
#### Improvements / TODO's

Currently this can only be used 'after the fact' - when new binaries are uploaded to getmonero. Providing a copy of the Gitian-built CLI binaries is something in process at the moment. This will let people reproduce the installer before it is released. When [this pull request](https://github.com/monero-project/monero/pull/8602) from selsta is merged, we can reproduce/confirm hashes of the installer before it's actually released.
