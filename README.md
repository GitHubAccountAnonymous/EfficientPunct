# EfficientPunct

This repository holds the code for our paper "Efficient Ensemble Architecture for Multimodal Embeddings in Punctuation Restoration using Time-Delay Neural Networks", submitted to ASRU 2023.

Some familiarity with Kaldi is highly recommended for usage of the EfficientPunct framework. You can find documentation of Kaldi at [https://kaldi-asr.org/](https://kaldi-asr.org/).

## Installation

1. Install [Kaldi](https://kaldi-asr.org/) by following instructions [here](https://github.com/kaldi-asr/kaldi). Let the root Kaldi directory be referred to in the following documentation as `kaldi/`.
2. Run the following commands:
```bash
cd kaldi/egs/tedlium
git clone https://github.com/GitHubAccountAnonymous/EfficientPunct
mv EfficientPunct/* s5_r3/
rm -rf EfficientPunct
# The framework of EfficientPunct is now located in kaldi/egs/tedlium/s5_r3.
cd s5_r3
```
3. Download an additional zip file from [this Google Drive link](https://drive.google.com/uc?id=17_kbtdBJrb-5vmivgU4L5QycWViXftRP) and place it inside `kaldi/egs/tedlium/s5_r3/`.
4. Run the following commands:
```bash
unzip additional.zip
rm additional.zip steps utils
rm -r conf
mv additional/* ./
rm -r additional
```

From now on, we will refer to the `kaldi/egs/tedlium/s5_r3` directory as simply `s5_r3/`.

## Data Preparation

Depending on whether you're using data for training or inference, you should use either the `custom_train` and `custom_train_text` or `custom_predict` and `custom_predict_text` subdirectories, respectively. For example, `s5_r3/data` and `s5_r3/db` contain these subdirectories to separately hold each data split. In the following documentation, let `[split]` be either `train` or `predict`, depending on your situation.

- Place each utterance's audio (`.wav` files) in `s5_r3/db/custom_[split]`. Each filename should be of the format `[utterance-id].wav`. 
- Place each utterance's text (`.txt` files) in `s5_r3/db/custom_[split]_text`. Each filename should be of the format `[utterance-id].txt`, and each file should simply contain a single line with the utterance's transcription.
- Create `s5_r3/data/custom_[split]/utt2spk`, a text file with one line for each utterance, and each line should be of the format `[utterance-id] [spk-id]`.
Here,
- `[utterance-id]` is a unique identifier for the utterance.
- `[spk-id]` is the speaker ID. This should be unique for each speaker.
