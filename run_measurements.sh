#!/bin/bash
# Memory, Disk, and Network Measurements
# CloudLab Assignment

OUTPUT="results.txt"
NODE1="node1"   # replace with actual hostname of the other node

echo "===== Installing Required Tools ====="
sudo apt-get update -y
sudo apt-get install -y ioping fio hdparm iperf iputils-ping wget tar

# Download and extract MLC if missing
if [ ! -f "./mlc_v3.9/mlc" ]; then
    echo "Downloading Intel MLC..."
    wget -q https://downloadmirror.intel.com/736634/mlc_v3.9.tgz -O mlc_v3.9.tgz
    cd mlc_v3.9
fi

echo "===== Memory Measurements =====" > $OUTPUT
echo "--- Total Physical Memory ---" >> $OUTPUT
cat /proc/meminfo | grep MemTotal >> $OUTPUT

echo "--- DRAM Latency ---" >> $OUTPUT
sudo ./mlc_v3.9/mlc --latency >> $OUTPUT 2>&1 || echo "MLC latency test failed" >> $OUTPUT

echo "--- DRAM Bandwidth ---" >> $OUTPUT
sudo ./mlc_v3.9/mlc --bandwidth_matrix >> $OUTPUT 2>&1 || echo "MLC bandwidth test failed" >> $OUTPUT

echo "" >> $OUTPUT
echo "===== Local Disk Measurements =====" >> $OUTPUT

echo "--- Disk Latency (ioping) ---" >> $OUTPUT
ioping -c 20 /tmp/ >> $OUTPUT 2>&1 || echo "ioping test failed" >> $OUTPUT

echo "--- Disk Read Bandwidth (fio) ---" >> $OUTPUT
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 \
    --name=fiotest --filename=testfio --bs=4k --iodepth=64 \
    --size=1G --readwrite=read >> $OUTPUT 2>&1 || echo "fio test failed" >> $OUTPUT

echo "--- Disk Specs (hdparm) ---" >> $OUTPUT
sudo hdparm -I /dev/sda >> $OUTPUT 2>&1

echo "" >> $OUTPUT
echo "===== Network Measurements =====" >> $OUTPUT

echo "--- Network Latency (ping $NODE1) ---" >> $OUTPUT
ping -c 10 $NODE1 >> $OUTPUT 2>&1

echo "--- Network Bandwidth (iperf node0 → node1) ---" >> $OUTPUT
for BW in 10m 50m 100m 500m 1g; do
    echo "### Testing bandwidth $BW ###" >> $OUTPUT
    ssh $NODE1 "nohup iperf -s -i 1 -w 4M -u > /tmp/iperf_server.log 2>&1 &"
    sleep 3
    iperf -c $NODE1 -e -i 1 -u -b $BW >> $OUTPUT 2>&1
    ssh $NODE1 "pkill iperf"
done

echo "--- Network Bandwidth (iperf node1 → node0) ---" >> $OUTPUT
for BW in 10m 50m 100m 500m 1g; do
    echo "### Testing bandwidth $BW ###" >> $OUTPUT
    nohup iperf -s -i 1 -w 4M -u > /tmp/iperf_server.log 2>&1 &
    SERVER_PID=$!
    sleep 3
    ssh $NODE1 "iperf -c $(hostname) -e -i 1 -u -b $BW" >> $OUTPUT 2>&1
    if ps -p $SERVER_PID > /dev/null 2>&1; then
        kill $SERVER_PID
    fi
done

echo "" >> $OUTPUT
echo "===== END OF MEASUREMENTS =====" >> $OUTPUT

