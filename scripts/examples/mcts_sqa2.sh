#!/usr/bin/env bash
#
# Copyright 2023 PKU-Alignment Team. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

if [ -z "${BASH_VERSION}" ]; then
	echo "Please use bash to run this script." >&2
	exit 1
fi

set -x

SCRIPT_DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
export PYTHONPATH="${ROOT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"
export LOGLEVEL="${LOGLEVEL:-WARNING}"

ACTOR_MODEL_NAME_OR_PATH="/home/users/nus/e0672129/scratch/MCTS-DPO/outputs/experiments/sqa/mistral-online-sc/steps2048"
ACTOR_REF_MODEL_NAME_OR_PATH="akjindal53244/Arithmo-Mistral-7B"
REWARD_MODEL_NAME_OR_PATH=$ACTOR_MODEL_NAME_OR_PATH
unset REWARD_CRITIC_MODEL_NAME_OR_PATH
OUTPUT_DIR="/home/users/nus/e0672129/scratch/MCTS-DPO/outputs/experiments/sqa/mistral-online-sc"
unset HOSTFILE
ZERO_STAGE=3
OFFLOAD="optimizer"

if [[ -z "${REWARD_CRITIC_MODEL_NAME_OR_PATH+x}" ]]; then
	REWARD_CRITIC_MODEL_NAME_OR_PATH="${REWARD_MODEL_NAME_OR_PATH}"
fi

mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" &>/dev/null && pwd)"
if [[ ! -f "${OUTPUT_DIR}/.gitignore" ]]; then
	echo '*' >"${OUTPUT_DIR}/.gitignore"
fi

cp -f "$0" "${OUTPUT_DIR}/script.sh"

if [[ -z "${WANDB_API_KEY}" ]]; then
	export WANDB_MODE="offline"
fi

MASTER_PORT_START=10000
MASTER_PORT_END=65535
MASTER_PORT="$(
	comm -23 \
		<(seq "${MASTER_PORT_START}" "${MASTER_PORT_END}" | sort) \
		<(ss -Htan | awk '{ print $4 }' | awk -F ':' '{ print $NF }' | sort -u) |
		shuf | head -n 1
)"

DEEPSPEED_ARGS=()
if [[ -n "${HOSTFILE+x}" ]]; then
	DEEPSPEED_ARGS+=("--hostfile" "${HOSTFILE}")
fi
DEEPSPEED_ARGS+=("--master_port" "${MASTER_PORT}")

exec 1> >(tee "${OUTPUT_DIR}/stdout.log" >&1) 2> >(tee "${OUTPUT_DIR}/stderr.log" >&2)

export WANDB_API_KEY="1396a7d2a29a8e8241dff6e0e6371f2ad61e11e2"
export WANDB_MODE=dryrun

export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,P2P

gpu_vis=0

deepspeed --include localhost:$gpu_vis --master_port $MASTER_PORT \
	--module mcts_rl.algorithms.mcts \
	--train_datasets SQA/train \
	--ptx_datasets ArithmoMCQ/train \
	--use_mcq \
	--actor_model_name_or_path "${ACTOR_MODEL_NAME_OR_PATH}" \
	--actor_ref_model_name_or_path "${ACTOR_REF_MODEL_NAME_OR_PATH}" \
	--resume_from_ckpt "${ACTOR_MODEL_NAME_OR_PATH}" \
	--scale_coeff 0.1 \
	--max_length 512 \
	--temperature 1.0 \
	--num_return_sequences 1 \
	--repetition_penalty 1.0 \
	--trust_remote_code True \
	--epochs 1 \
	--update_iters 1 \
	--save_interval 128 \
	--per_device_ptx_batch_size 4 \
	--per_device_prompt_batch_size 1 \
	--per_device_train_batch_size 1 \
	--gradient_accumulation_steps 32 \
	--actor_lr 4e-7 \
	--actor_weight_decay 0.05 \
	--actor_lr_scheduler_type cosine \
	--actor_lr_warmup_ratio 0.03 \
	--actor_gradient_checkpointing \
	--seed 42 \
	--kl_coeff 0.02 \
	--clip_range_ratio 0.2 \
	--clip_range_score 50.0 \
	--clip_range_value 5.0 \
	--ptx_coeff 0.0 \
	--output_dir "${OUTPUT_DIR}" \
	--log_type wandb \
	--log_project MCTS-DPO-MCQ-SQA-yuxi \
	--zero_stage "${ZERO_STAGE}" \
	--offload "${OFFLOAD}" \
	--bf16 True \
	--tf32 True \
	--max_new_tokens 512 \
	--n_iters 5 \
	--depth_limit 1 \
	--n_init_actions 8 \
	--n_actions 1 \
	--mcts_temperature 0.0

# --force_terminating_on_depth_limit \
# --per_device_eval_batch_size 1 \
# --need_eval \
# --eval_datasets PRM800K/test \
