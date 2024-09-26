#!/bin/bash

ROBOT_WORKING_DIRECTORY=/home/jetson/RoboSoccerPlatform/robot

source .env

ssh jetson@${RED_ROBOT_IP} "mkdir -p ${ROBOT_WORKING_DIRECTORY} && echo ${SERVER_IP} > ${ROBOT_WORKING_DIRECTORY}/SERVER_IP && echo ${RED_ROBOT_SERVER_PORT} > ${ROBOT_WORKING_DIRECTORY}/SERVER_PORT"
scp robot/main.py robot/robo_soccer.sh jetson@${RED_ROBOT_IP}:${ROBOT_WORKING_DIRECTORY}
ssh jetson@${GREEN_ROBOT_IP} "mkdir -p ${ROBOT_WORKING_DIRECTORY} && echo ${SERVER_IP} > ${ROBOT_WORKING_DIRECTORY}/SERVER_IP && echo ${GREEN_ROBOT_SERVER_PORT} > ${ROBOT_WORKING_DIRECTORY}/SERVER_PORT"
scp robot/main.py robot/robo_soccer.sh jetson@${GREEN_ROBOT_IP}:${ROBOT_WORKING_DIRECTORY}
