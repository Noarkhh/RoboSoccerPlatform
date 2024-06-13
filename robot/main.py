from adafruit_servokit import ServoKit, ContinuousServo, Servo
from typing import Tuple
import time
import socket
import struct

i2c_address = 0x40
steering_channel = 0
throttle_channel = 1
server_ip = "192.168.43.204"
server_port = 20000

def setup():
    kit = ServoKit(channels=16, address=i2c_address)
    steering_motor = kit.servo[steering_channel]
    throttle_motor = kit.continuous_servo[throttle_channel]
    print("Motors initialized")
    
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        connect_socket(sock, 1)
        print("Socket connected")
        loop(sock, steering_motor, throttle_motor)

def loop(sock: socket, steering_servo: Servo, throttle_motor: ContinuousServo) -> None:
    while True:
        receive_instruction(sock, steering_servo, throttle_motor)

def connect_socket(sock: socket, timeout: int) -> None:
    try:
        sock.connect((server_ip, server_port))
    except ConnectionRefusedError:
        print(f"Connection refused, retrying in {timeout} s...")
        time.sleep(timeout)
        connect_socket(sock, timeout * 2)

def receive_instruction(sock: socket, steering_servo: Servo, throttle_motor: ContinuousServo) -> None:
    command_binary = sock.recv(16)
    
    steering_servo_angle, throttle_motor_throttle = parse_instruction(command_binary)

    steering_servo.angle = steering_servo_angle
    throttle_motor.throttle = throttle_motor_throttle

def parse_instruction(instruction_binary: bytes) -> Tuple[float, float]:
    steering_instruction, throttle_instruction = struct.unpack(">dd", instruction_binary)

    steering_servo_angle = -clip(steering_instruction) * 180 - 90
    throttle_motor_throttle = clip(throttle_instruction)

    return steering_servo_angle, throttle_motor_throttle

def clip(value: float, lower_bound: float = -1.0, upper_bound: float = 1.0) -> float:
    return min(max(value, lower_bound), upper_bound)

if __name__ == "__main__":
    setup()
