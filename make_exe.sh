#!/bin/bash
GH_KEY=$1

# clean up old build dir
rm -rf bin

# Get most recent runid from monero/gitian.yml and monero-gui/build.yml
get_workflow_runs(){ page=$1 repo=$2 workflow=$3
  FOUND_BIN=0
  PREPARE=0
  runs=$(curl \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: token ${GH_KEY}" \
    https://api.github.com/repos/monero-project/${repo}/actions/runs?page=$page)

  for row in $(echo "${runs}" | jq -r '.workflow_runs[] | @base64'); do
      _jq() {
       echo ${row} | base64 --decode | jq -r ${1}
      }
      if [[ $(_jq '.path') = ".github/workflows/$workflow" ]]; then 
          TAG=$(_jq '.head_branch')
          echo $TAG
          is_v=${TAG:0:1}
          is_p=${TAG:0:9}
          IFS='.' read -ra SPLIT <<< "$TAG"
          if [[ $is_v = "v" ]] || [[ $is_p = "prepare-v" ]] && [[ ${#SPLIT[@]} -eq 4 ]]; then
              RUNID=$(_jq '.id')
              FOUND_BIN=1
              if [[ $is_p = "prepare-v" ]]; then
                TAG="${TAG/prepare-v/v}"
                PREPARE=1
                echo "Tag is now ${TAG}"
              fi    
              break
          fi
      fi
  done
  if [[ $FOUND_BIN -eq 0 ]]; then
      ((page+=1))
      get_workflow_runs $page $repo $workflow
  else
    FOUND_BIN=0
  fi
}
get_workflow_runs 1 monero-gui "build.yml"
RUN_ID=$RUNID
get_workflow_runs 1 monero "gitian.yml"
GITIAN_ID=$RUNID

# Download docker-windows-static
download_artifact(){ run_id=$1 repo=$2 get_name=$3 save_as=$4 gh_key=$5
  workflow_run=$(curl \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/monero-project/${repo}/actions/runs/${run_id}/artifacts)
  num=0
  for artifact_name in $(echo ${workflow_run} | jq -r '.artifacts[].name'); do
    if [[ "${artifact_name}" == "${get_name}" ]]; then
      URL=$(echo ${workflow_run} | jq -r ".artifacts[${num}].archive_download_url")
      TAG=$(echo ${workflow_run} | jq -r ".artifacts[${num}].workflow_run.head_branch")
      break
    fi
    ((num+=1))
  done
  curl \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: token ${gh_key}" \
    -L -o "${save_as}" \
    "${URL}"
  echo $URL
}

declare -A innoFiles
innoFiles["Default.isl"]="179da3422d7bbb65bb2052f9c0b370ab66ddd6f24693d90accbd7d7d73d4f1a4" 
innoFiles["ISCC.exe"]="0d02e30a6ad432a50eb86f1ecf330147046e671de340bcb43a170fecbd19bf51" 
innoFiles["ISCmplr.dll"]="5ea9bb338795bffa33da5581e5fe1c976a561f6dc32105635dcd518fbb5a33b4" 
innoFiles["islzma.dll"]="0b2e19e473a47e10578b05a2f3b43ad96603f3ee1e397c06a280c3b7458a76e2" 
innoFiles["ISPPBuiltins.iss"]="a7c5a10f4aac60862082985cfdf8bc5e703fa7fb9cfff4e1deb1d9452862057f" 
innoFiles["Setup.e32"]="088622096c373250d04e46de5cda072a921a89900c57988bbe52f1e308e48043" 
innoFiles["SetupLdr.e32"]="86154d725c21660f220e957eb6dcaf73ca609eef486dcdce6d5d7c286abd03d5" 
innoFiles["ISPP.dll"]="1be06b60090221d7a7d236d374ab4ff7e6a56013107f806be4bea2b79dad3703" 
innoFiles["opengl32sw.dll"]="963641a718f9cae2705d5299eae9b7444e84e72ab3bef96a691510dd05fa1da4" 

echo "Verify InnoSetup files" 
cd utils
for f in *; do
  hash=$(sha256sum $f | awk '{print $1}')
  if [[ "${innoFiles[$f]}" != "${hash}" ]]; then
    echo "Hash mismatch $f"
    exit
  else
    echo "Verified $f"
  fi
done 
cd ..

#download artifact also sets the TAG variable
download_artifact $RUN_ID monero-gui "docker-windows-static" "docker-windows-static" "${GH_KEY}"
download_artifact $GITIAN_ID monero "Windows" "Windows" "${GH_KEY}"
#Extract static files to frombuild
unzip "docker-windows-static" -d frombuild
# Download CLI/PDF file(s)
#wget -q "https://gui.xmr.pm/files/cli/${TAG}/monero-win-x64-${TAG}.zip" 
unzip "Windows"

wget -q "https://github.com/monero-ecosystem/monero-GUI-guide/releases/download/v1.9/monero-gui-wallet-guide.pdf" 
unzip "monero-x86_64-w64-mingw32-${TAG}.zip" -d clifiles

# Create lowgfx bat file with heredoc (windows powershell uses \r\n)
cr=$'\r'
tee "start-low-graphics-mode.bat" <<EOF
@echo off$cr
$cr
set QMLSCENE_DEVICE=softwarecontext$cr
$cr
start /b monero-wallet-gui.exe$cr
EOF

mkdir -p "dummy/monero-gui-${TAG}/extras"
HEAD="clifiles/monero-x86_64-w64-mingw32-${TAG}"
OUT="dummy/monero-gui-${TAG}"
echo "HEAD is ${HEAD}"
license="${HEAD}/LICENSE"
monerod="${HEAD}/monerod.exe"

mv $license "${OUT}/"
mv $monerod "${OUT}/"

readme="${HEAD}/README.md"; rm "${readme}"
anon="${HEAD}/ANONYMITY_NETWORKS.md"; rm "${anon}"
dest="dummy/monero-gui-${TAG}"
cp monero-gui-wallet-guide.pdf "${dest}/"
cp frombuild/monero-wallet-gui.exe "${dest}/"
cp utils/opengl32sw.dll "${dest}/"
cp start-low-graphics-mode.bat "${dest}/"

ls ${HEAD}
for f in "${HEAD}/*"; do
  echo "$f"
  cp $f "dummy/monero-gui-${TAG}/extras"
done

dest="dummy/monero-gui-${TAG}"
mkdir inno; cd inno
git init
git remote add -f origin https://github.com/monero-project/monero-gui
git sparse-checkout init
git sparse-checkout set "installers/windows"
git pull origin master
mkdir -p installers/windows/bin
cd ..
for f in "${dest}/*"; do
  cp -r $f "inno/installers/windows/bin"
done
strip_v="${TAG:1}"
inno_file='inno/installers/windows/Monero.iss'
# mistake in v0.18.1.1. to reproduce hash use line 13
# -e '13 cTouchDate=none \nTouchTime=none' \
lines="$(cat $inno_file)"
SAVEIFS=$IFS
IFS=$'\n'
lines=($lines)
IFS=$SAVEIFS
num=1
setup="[Setup]"
define="#define GuiVersion GetFileVersion(\"bin\monero-wallet-gui.exe\")"
readme="Source: {#file AddBackslash(SourcePath) + \"ReadMe.htm\"}; DestDir: \"{app}\"; DestName: \"ReadMe.htm\"; Flags: ignoreversion"

for line in "${lines[@]}"; do
    if [[ "$line" = "$setup"* ]] ; then
      echo "we found setup $num"
      setup=$num
    elif [[ "$line" = "$define"* ]] ; then
      echo "we found define $num"
      define=$num
    elif [[ "$line" = "$readme"* ]] ; then
      echo "we found readme $num"
      readme=$num
      sed -i "${readme} cSource: \"ReadMe.htm\"; DestDir: \"{app}\"; Flags: ignoreversion" ${inno_file}
    fi
    ((num+=1))
done

sed -i \
-e "${define} c#define GuiVersion \"${strip_v}\"" \
-e "${setup} c\[Setup\] \nTouchDate=none \nTouchTime=none" ${inno_file}

for f in "utils/*"; do
  cp $f "inno/installers/windows"
done
HOMEDIR="$(pwd)"
##
## Get time offset
##
offset=$(date +%z | sed 's/0//g')
stamp=$(stat -c '%y' frombuild/monero-wallet-gui.exe) 
echo "offset is $offset"
if [[ "$offset" = "+" ]]; then
  offset="+0"
fi
corrected_stamp=$(date -d"${stamp} ${offset} hours" +"%Y%m%d%H%M.%S")

for f in "inno/installers/windows/*" "inno/installers/windows/**/*" "inno/installers/windows/**/**/*"; do
  echo $f
  touch -t "${corrected_stamp}" $f
done

wine inno/installers/windows/ISCC.exe inno/installers/windows/Monero.iss

mkdir bin
mv  inno/installers/windows/Output/mysetup.exe "bin/monero-gui-install-win-x64-${TAG}.exe"

hash_exe=$(sha256sum bin/monero-gui-install-win-x64-${TAG}.exe| awk '{print $1}')
echo "Hash of gitian built cli zip:"
sha256sum monero-x86_64-w64-mingw32-${TAG}.zip
echo "# ---------------------"
echo "# Monero GUI installer hash:"
echo "# ${hash_exe}"
echo "# ---------------------"
if [[ $PREPARE -eq 1 ]]; then
  echo "Caution: we are using build-prepare script not official tag"
fi

# cleanup

rm -rf clifiles
rm -rf dummy
rm -rf frombuild
rm -rf inno
rm docker-windows-static
rm Windows
rm *zip
rm start-low-graphics-mode.bat
rm monero-gui-wallet-guide.pdf
