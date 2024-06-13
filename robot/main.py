from adafruit_servokit import ServoKit, ContinuousServo
import time
import socket
import struct

i2c_address = 0x40
steering_channel = 0
throttle_channel = 1
server_ip = "192.168.43.204"
server_port = 60606

def setup():
    kit = ServoKit(channels=16, address=i2c_address)
    steering_motor = kit.continuous_servo[steering_channel]
    throttle_motor = kit.continuous_servo[throttle_channel]
    print("Motors initialized")
    
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        connect_socket(sock, 1)
        print("Socket connected")
        loop(sock, steering_motor, throttle_motor)

def loop(sock: socket, steering_motor: ContinuousServo, throttle_motor: ContinuousServo) -> None:
    while True:
        receive_command(sock, steering_motor, throttle_motor)

def connect_socket(sock: socket, timeout: int) -> None:
    try:
        sock.connect((server_ip, server_port))
    except ConnectionRefusedError:
        print(f"Connection refused, retrying in {timeout} s...")
        time.sleep(timeout)
        connect_socket(sock, timeout * 2)

def receive_command(sock: socket, steering_motor: ContinuousServo, throttle_motor: ContinuousServo) -> None:
    command_binary = sock.recv(16)
    
    steering_command, throttle_command = parse_instruction(command_binary)

    steering_motor.throttle = steering_command
    throttle_motor.throttle = throttle_command

def parse_instruction(instruction_binary):
    steering_instruction, throttle_instruction = struct.unpack(">dd", instruction_binary)
    steering_instruction = min(1.0, max(-1.0, steering_instruction))
    throttle_instruction = min(1.0, max(-1.0, throttle_instruction))
    print(f"steer: {steering_instruction}, throttle: {throttle_instruction}")
    return steering_instruction, throttle_instruction

if __name__ == "__main__":
    setup()
