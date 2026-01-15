#!/bin/bash

conda create -n tf-gpu python=3.10 -y
conda activate tf-gpu
pip install "tensorflow[and-cuda]"

python - <<'EOF'
import tensorflow as tf
print(tf.config.list_physical_devices('GPU'))
EOF
