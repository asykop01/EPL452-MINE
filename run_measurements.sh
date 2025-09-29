#!/bin/bash
# Memory, Disk, and Network Measurements
# CloudLab Assignment

OUTPUT="results.txt"
NODE1="node1"   # replace with actual hostname of the other node

echo "===== Memory Measurements =====" > $OUTPUT
echo "--- Total Physical Memory ---" >> $OUTPUT
cat /proc/meminfo | grep MemTotal >> $OUTPUT

echo "--- DRAM Latency ---" >> $OUTPUT
sudo ./mlc_v3.9/mlc --latency >> $OUTPUT 2>&1

echo "--- DRAM Bandwidth ---" >> $OUTPUT
sudo ./mlc_v3.9/mlc --bandwidth_matrix >> $OUTPUT 2>&1

echo "" >> $OUTPUT
echo "===== Local Disk Measurements =====" >> $OUTPUT

echo "--- Disk Latency (ioping) ---" >> $OUTPUT
ioping -c 20 /tmp/ >> $OUTPUT 2>&1

echo "--- Disk Read Bandwidth (fio) ---" >> $OUTPUT
fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 \
    --name=fiotest --filename=testfio --bs=4k --iodepth=64 \
    --size=1G --readwrite=read >> $OUTPUT 2>&1

echo "--- Disk Specs (hdparm) ---" >> $OUTPUT
sudo hdparm -I /dev/sda >> $OUTPUT 2>&1

echo "" >> $OUTPUT
echo "===== Network Measurements =====" >> $OUTPUT

echo "--- Network Latency (ping $NODE1) ---" >> $OUTPUT
ping -c 10 $NODE1 >> $OUTPUT 2>&1

echo "--- Network Bandwidth (iperf) ---" >> $OUTPUT
# Start iperf server on NODE1 in background
ssh $NODE1 "nohup iperf -s -i 1 -w 4M -u > /tmp/iperf_server.log 2>&1 &"

# Wait a bit for server to start
sleep 3

# Run client test from node0 to node1
iperf -c $NODE1 -e -i 1 -u -b 100m >> $OUTPUT 2>&1

# Kill iperf server on node1
ssh $NODE1 "pkill iperf"

echo "--- Network Bandwidth (iperf reverse test) ---" >> $OUTPUT
# Start iperf server on node0 in background
nohup iperf -s -i 1 -w 4M -u > /tmp/iperf_server.log 2>&1 &
SERVER_PID=$!

# Wait a bit for server to start
sleep 3

# Run client test from node1 to node0
ssh $NODE1 "iperf -c $(hostname) -e -i 1 -u -b 100m" >> $OUTPUT 2>&1

# Kill iperf server on node0
kill $SERVER_PID

echo "" >> $OUTPUT
echo "===== END OF MEASUREMENTS =====" >> $OUTPUT
