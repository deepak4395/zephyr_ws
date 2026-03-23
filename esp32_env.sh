#!/usr/bin/env sh
# esp32_env.sh — Source this to set up ESP32 build environment
SDK_DIR="/CG_Ubunutu/learn_zephyr/zephyr_ws/zephyr-sdk-0.16.8"
export ZEPHYR_SDK_INSTALL_DIR="$SDK_DIR"
source "$SDK_DIR/setup.sh"
echo "ESP32 environment configured."
echo "  ZEPHYR_SDK_INSTALL_DIR=$ZEPHYR_SDK_INSTALL_DIR"
