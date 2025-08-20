import socket
import struct
import time
import math
import numpy as np

UDP_IP = "127.0.0.1"
UDP_PORT_SEND = 12345  # To Simulink target port: 12345
UDP_PORT_RECEIVE_STATE = 12346  # Python received port from Simulink state: 12346
UDP_PORT_RECEIVE_CONTROL = 12347  # Python received port from MATLAB shake control: 12347
UDP_PORT_SEND_CONFIRM = 12348  # To MATLAB target port: 12348
UDP_PORT_CONTROL_SEND = 12349  # Python self send port: 12349

# 创建并绑定 socket
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((UDP_IP, UDP_PORT_RECEIVE_STATE))
    print(f"State sock bound to {UDP_IP}:{UDP_PORT_RECEIVE_STATE}")
except socket.error as e:
    print(f"State sock 绑定失败: {e}")
    exit(1)

try:
    control_send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    control_send_sock.bind((UDP_IP, UDP_PORT_CONTROL_SEND))
    print(f"Control send sock bound to {UDP_IP}:{UDP_PORT_CONTROL_SEND}")
except socket.error as e:
    print(f"Control send sock 绑定失败: {e}")
    sock.close()
    exit(1)

try:
    control_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    control_sock.bind((UDP_IP, UDP_PORT_RECEIVE_CONTROL))
    print(f"Control sock bound to {UDP_IP}:{UDP_PORT_RECEIVE_CONTROL}")
except socket.error as e:
    print(f"Control sock 绑定失败: {e}")
    sock.close()
    control_send_sock.close()
    exit(1)

confirm_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

current_episode = 0
current_status = 0

handshake_received = False
while not handshake_received:
    try:
        control_sock.settimeout(3.0)
        data, addr = control_sock.recvfrom(16)
        print(f"收到原始字节: {list(data)}, Address: {addr}")
        if len(data) == 16:
            first_struct = struct.unpack('<d', data[:8])[0]
            second_struct = struct.unpack('<d', data[8:])[0]
            print(f"手动解析数据 (struct): ({first_struct}, {second_struct}), Address: {addr}")
            first_np = np.frombuffer(data[:8], dtype=np.float64, count=1)[0]
            second_np = np.frombuffer(data[8:], dtype=np.float64, count=1)[0]
            print(f"手动解析数据 (numpy): ({first_np}, {second_np}), Address: {addr}")
            if addr[1] == 12350:
                if first_struct == 0.0 and second_struct == -1.0:
                    print("收到 MATLAB 握手信号")
                    confirm_sock.sendto(struct.pack('<dd', 0, -1), (UDP_IP, UDP_PORT_SEND_CONFIRM))
                    print(f"发送握手确认到 {UDP_IP}:{UDP_PORT_SEND_CONFIRM}")
                    handshake_received = True
                else:
                    print(f"数据不匹配，预期 [0, -1]，收到 [{first_struct}, {second_struct}]")
            else:
                print(f"来自意外端口: {addr[1]}，预期 12350")
        else:
            print(f"数据长度错误: {len(data)} 字节")
    except socket.timeout:
        print("等待握手信号...")
        continue

if handshake_received:
    print("发送测试控制信号到 Simulink")
    control_send_sock.sendto(struct.pack('<d', 0.0), (UDP_IP, UDP_PORT_SEND))
    time.sleep(0.1)

while current_episode <= 50:
    try:
        control_sock.settimeout(0.1)
        data, addr = control_sock.recvfrom(16)
        print(f"收到原始字节: {list(data)}, Address: {addr}")
        unpacked = struct.unpack('<dd', data)
        print(f"收到控制数据: {unpacked}, Address: {addr}")
        new_episode = int(unpacked[0])
        new_status = int(unpacked[1])

        if new_episode == 51 and new_status == -2:
            print("收到 MATLAB 结束信号")
            confirm_sock.sendto(struct.pack('<dd', 51, -2), (UDP_IP, UDP_PORT_SEND_CONFIRM))
            print(f"发送结束确认到 {UDP_IP}:{UDP_PORT_SEND_CONFIRM}")
            break

        if new_episode != current_episode or new_status != current_status:
            current_episode = new_episode
            current_status = new_status
            print(f"收到控制: Episode {current_episode}, Status {current_status}")
    except socket.timeout:
        continue

    if current_status == 1:
        print(f"Episode {current_episode} 运行中，开始发送/接收")
        while current_status == 1:
            sim_t = 0.0
            try:
                sock.settimeout(0.01)
                data, addr = sock.recvfrom(16)
                unpacked = struct.unpack('<dd', data)
                state = unpacked[0]
                sim_t = unpacked[1]
                print(f"Episode {current_episode}: 接收状态 {state}, sim_t {sim_t}")
            except socket.timeout:
                pass

            control = math.sin(sim_t)
            control_send_sock.sendto(struct.pack('<d', control), (UDP_IP, UDP_PORT_SEND))

            try:
                control_sock.settimeout(0.1)
                data, addr = control_sock.recvfrom(16)
                print(f"收到原始字节: {list(data)}, Address: {addr}")
                unpacked = struct.unpack('<dd', data)
                print(f"收到控制数据: {unpacked}, Address: {addr}")
                new_status = int(unpacked[1])
                if new_status != current_status:
                    current_status = new_status
                    print(f"更新 Status: {current_status}")
            except socket.timeout:
                pass

            time.sleep(0.01)

        print(f"Episode {current_episode} 结束")

# 清理
sock.close()
control_send_sock.close()
control_sock.close()
confirm_sock.close()
print("所有 socket 已关闭")