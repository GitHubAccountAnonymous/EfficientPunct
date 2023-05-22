# EfficientPunct

This repository holds the code for our paper "Efficient Ensemble Architecture for Multimodal Embeddings in Punctuation Restoration using Time-Delay Neural Networks", submitted to ASRU 2023.

Some familiarity with Kaldi is highly recommended for usage of the EfficientPunct framework. You can find documentation of Kaldi at [https://kaldi-asr.org/](https://kaldi-asr.org/).

## Installation

1. Install [Kaldi](https://kaldi-asr.org/) by following instructions [here](https://github.com/kaldi-asr/kaldi). Let the root Kaldi directory be referred to in the following documentation as `kaldi/`.
2. Execute the commands:
  ```bash
  cd kaldi/egs/tedlium
  git clone https://github.com/GitHubAccountAnonymous/EfficientPunct
  mv EfficientPunct/* s5_r3/
  rm -rf EfficientPunct
  # The framework of EfficientPunct is now located in kaldi/egs/tedlium/s5_r3.
  cd s5_r3
  ```
