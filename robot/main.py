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

def parse_instruction(instruction_binary: bytes) -> Tuple[float, float]:
    steering_instruction, throttle_instruction = struct.unpack(">dd", instruction_binary)

    steering_servo_angle = clip((-steering_instruction + 1.0) * 90.0, 0.0, 180.0)
    throttle_motor_throttle = clip(throttle_instruction, -1.0, 1.0)
    print(steering_servo_angle)

    return steering_servo_angle, throttle_motor_throttle

def clip(value: float, lower_bound: float, upper_bound: float) -> float:
    return min(max(value, lower_bound), upper_bound)

class Robot:
    sock: socket
    steering_servo: Servo
    throttle_motor: ContinuousServo

    def __init__(self) -> None:
        self.setup()
        self.loop()

    def setup(self):
        kit = ServoKit(channels=16, address=i2c_address)
        print("ServoKit initialized")
        self.steering_servo = kit.servo[steering_channel]
        print("Steering servo initialized")
        self.throttle_motor = kit.continuous_servo[throttle_channel]
        print("Throttle motor initialized")
        
        self.establish_connection()

    def loop(self) -> None:
        while True:
            self.receive_instruction()

    def establish_connection(self) -> None:
        timeout = 2
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        while True:
            try:
                self.sock.connect((server_ip, server_port))
                print("Connection established")
                return
            except ConnectionRefusedError:
                print(f"Connection refused, retrying in {timeout} s...")
                time.sleep(timeout)
                timeout = min(timeout + 2, 20)


    def receive_instruction(self) -> None:
        command_binary = self.sock.recv(16)
        if command_binary == b"":
            print("Connection closed, retrying")
            self.sock.close()
            self.establish_connection()
            return
        
        steering_servo_angle, throttle_motor_throttle = parse_instruction(command_binary)

        self.steering_servo.angle = steering_servo_angle
        self.throttle_motor.throttle = throttle_motor_throttle


if __name__ == "__main__":
    Robot()
