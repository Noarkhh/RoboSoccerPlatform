#!/bin/bash

ROBOT_PATH=/home/jetson/RoboSoccerPlatform/robot

cd $ROBOT_PATH
git checkout improve-robot
git pull
$ROBOT_PATH/venv/bin/python $ROBOT_PATH/main.py