# ssh -i ~/Downloads/alpha-key.pem ec2-user@54.152.239.227
yum install git -y
yum install python3-pip
pip3 install crytic-compile
pip3 install slither-analyzer --user
mkdir ~/git
cd ~/git
git clone -b echidna https://github.com/poolshark-protocol/cover.git
curl -fL https://github.com/crytic/echidna/releases/download/v2.2.1/echidna-2.2.1-Linux.zip -o echidna.zip
unzip echidna.zip
tar xvf echidna.tar.gz
solc-select install 0.8.13
solc-select use 0.8.13
nohup ./echidna contracts/CoverEchidnaPool.sol --config contracts/test/echidna/config.yaml --corpus-dir corpus --workers 12 &
top -o %MEM -c
tail -f nohup.out -n 100