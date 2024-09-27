from adafruit_servokit import ServoKit, ContinuousServo, Servo
from typing import Tuple
from datetime import datetime
import logging
from pathlib import Path
import time
import socket
import struct

i2c_address = 0x40
steering_channel = 0
throttle_channel = 1
logger = logging.getLogger("robo_soccer")

def parse_instruction(instruction_binary: bytes) -> Tuple[float, float]:
    steering_instruction, throttle_instruction = struct.unpack(">dd", instruction_binary)

    steering_servo_angle = clip((-steering_instruction + 1.0) * 90.0, 0.0, 180.0)
    throttle_motor_throttle = clip(throttle_instruction, -1.0, 1.0)

    return steering_servo_angle, throttle_motor_throttle

def clip(value: float, lower_bound: float, upper_bound: float) -> float:
    return min(max(value, lower_bound), upper_bound)

class Robot:
    sock: socket.socket
    steering_servo: Servo
    throttle_motor: ContinuousServo

    def __init__(self) -> None:
        self.setup()
        self.loop()

    def setup(self):
        log_file = f"/tmp/robo_soccer_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.log"
        logging.basicConfig(filename=log_file, level=logging.DEBUG)

        kit = ServoKit(channels=16, address=i2c_address)
        logger.info("ServoKit initialized")
        self.steering_servo = kit.servo[steering_channel]
        logger.info("Steering servo initialized")
        self.throttle_motor = kit.continuous_servo[throttle_channel]
        logger.info("Throttle motor initialized")
        
        self.establish_connection()

    def loop(self) -> None:
        while True:
            try:
                self.receive_instruction()
            except ConnectionError as e:
                logger.warning(f"Caught ConnectionError: {e}, reconnecting")
                self.sock.close()
                self.establish_connection()
            except Exception as e:
                logger.error(f"Caught Exception: {e}, ignoring")

    def establish_connection(self) -> None:
        timeout = 2
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        while True:
            try:
                server_ip = Path("SERVER_IP").read_text()
                server_port = int(Path("SERVER_PORT").read_text())
                self.sock.connect((server_ip, server_port))
                logger.info("Connection established")
                return
            except ConnectionError as e:
                logger.warning(f"Connection refused: {e}, retrying in {timeout} s...")
            except Exception as e:
                logger.error(f"Caught Exception: {e}, ignoring and retrying in {timeout} s...")
            finally:
                time.sleep(timeout)

    def receive_instruction(self) -> None:
        command_binary = self.sock.recv(16)
        if command_binary == b"":
            logger.error("Connection closed, retrying")
            self.sock.close()
            self.establish_connection()
            return
        
        steering_servo_angle, throttle_motor_throttle = parse_instruction(command_binary)

        self.steering_servo.angle = steering_servo_angle
        self.throttle_motor.throttle = throttle_motor_throttle


if __name__ == "__main__":
    Robot()
