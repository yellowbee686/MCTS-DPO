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
"""PRM800K preference datasets."""

from __future__ import annotations

import os
from typing import ClassVar

from mcts_rl.datasets.base import RawDataset, RawSample, jsonlines_load


__all__ = [
    'PRM800KDataset',
    'PRM800KTrainDataset',
    'PRM800KTestDataset',
]

DATA_DIR = "/mnt/data/yuxi/math/prm800k/prm800k/data/latest"


class PRM800KDataset(RawDataset):
    SPLIT: ClassVar[str]
    PATH: ClassVar[str]

    def __init__(self, path: str | None = None) -> None:
        self.data = jsonlines_load(os.path.join(DATA_DIR, f'preference_prm_{self.SPLIT}.jsonl'))

    def __getitem__(self, index: int) -> RawSample:
        data = self.data[index]
        prompt = data['prompt']
        # prompt = f'{prompt}\n\nANSWER: {data["solution"]["solution"]}\nThe answer is {data["solution"]["answer"]}\n\nQUESTION: {prompt}'
        # from mcts_rl.utils import extract_answer, math_equal
        # if not math_equal(extract_answer(data.get('generation-base', 'None')), data.get('answer', None)):
        #     prompt = '{}\n\nANSWER: {}\n\nREVISION REQUEST: Please revise the above answer to get the correct answer {}.'.format(
        #         prompt, data.get('generation-base', 'None'), data.get('answer', 'None'),
        #     )
        # import ipdb; ipdb.set_trace()
        return RawSample(
            input=prompt,
            # answer=data['response_0'],
            answer=data['solution']['solution'],
            other_answer=data['response_1'],
            better=int(data['better_response_id']) == 0,
            safer=int(data['better_response_id']) == 0,
            is_safe=bool(data['is_response_0_correct_answer']),
            is_other_safe=bool(data['is_response_1_correct_answer']),
            final_answer=data.get('answer', None),
        )

    def __len__(self) -> int:
        return len(self.data)


class PRM800KTrainDataset(PRM800KDataset):
    NAME: str = 'PRM800K/train'
    ALIASES: tuple[str, ...] = ('OpenAI/PRM800K/train',)
    PATH: str = 'OpenAI/PRM800K'
    SPLIT: str = 'train'


class PRM800KTestDataset(PRM800KDataset):
    NAME: str = 'PRM800K/test'
    ALIASES: tuple[str, ...] = ('OpenAI/PRM800K/test',)
    PATH: str = 'OpenAI/PRM800K'
    SPLIT: str = 'test'
