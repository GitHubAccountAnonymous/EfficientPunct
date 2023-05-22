#!/usr/bin/env bash

. ./cmd.sh
. ./path.sh


set -e -o pipefail -u

nj=16
decode_nj=16
stage=0

. utils/parse_options.sh

if [ $stage -le 0 ]; then
  echo "===================="
  echo "Stage 0 starting"
  # python3 parse_singapore_txtwav.py ~/imda_national_speech_corpus/
  python3 parse_unipunc_txtwav.py train
  ./custom_train_extract_audio.sh
  echo "Stage 0 ending"
  echo ""
fi

if [ $stage -le 1 ]; then

  echo "===================="
  echo "Stage 1 starting"
  python3 create_text.py other custom_train

  utils/fix_data_dir.sh data/custom_train
  utils/utt2spk_to_spk2utt.pl data/custom_train/utt2spk > data/custom_train/spk2utt
  echo ';; empty.glm
  [FAKE]     =>  %HESITATION     / [ ] __ [ ] ;; hesitation token
  ' > data/custom_train/glm
  utils/fix_data_dir.sh data/custom_train
  utils/validate_data_dir.sh --no-feats --no-text data/custom_train
  echo "Stage 1 ending"
  echo ""
fi

# Feature extraction
if [ $stage -le 2 ]; then
  echo "===================="
  echo "Stage 2 starting"
  steps/make_mfcc_pitch.sh --nj $nj --mfcc-config conf/mfcc_hires.conf --cmd "$train_cmd" data/custom_train
  steps/compute_cmvn_stats.sh data/custom_train
  utils/fix_data_dir.sh data/custom_train

  echo "Stage 2 ending"
  echo ""
fi

if [ $stage -le 3 ]; then
  echo "===================="
  echo "Stage 3 starting"
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
    data/custom_train exp/nnet3_cleaned_1d/extractor \
    exp/nnet3_cleaned_1d/ivectors_custom_train
  echo "Stage 3 ending"
  echo ""
fi

if [ $stage -le 4 ]; then
  echo "===================="
  echo "Stage 4 starting"
  # Obtaining final hidden layer's output
  ./compute_output_custom.sh --nj $nj --iter upto12th \
    --online-ivector-dir exp/nnet3_cleaned_1d/ivectors_custom_train \
    data/custom_train exp/chain_cleaned_1d/tdnn1d_sp exp/chain_cleaned_1d/tdnn1d_sp/output12_custom_train
  echo "Stage 4 ending"
  echo ""
fi

if [ $stage -le 5 ]; then
  echo "===================="
  echo "Stage 5 starting"

  chain_dir=exp/chain_cleaned_1d
  steps/nnet3/align_custom.sh --nj $nj \
    data/custom_train \
    data/lang \
    $chain_dir/tdnn1d_sp \
    $chain_dir/tdnn1d_sp_custom_train_ali
  gunzip $chain_dir/tdnn1d_sp_custom_train_ali/ali.*.gz

  for JOB in $(seq 1 $nj)
  do
    ali-to-phones --ctm-output \
      $chain_dir/tdnn1d_sp/final.mdl \
      ark:$chain_dir/tdnn1d_sp_custom_train_ali/ali.$JOB \
      $chain_dir/tdnn1d_sp_custom_train_ali/ali.$JOB.ctm
  done

  echo "Stage 5 ending"
  echo ""
fi

if [ $stage -le 6 ]; then
  echo "===================="
  echo "Stage 6 starting"
  # Generating concatenated BERT+Kaldi embeddings
  if [ -d "embed_custom_train" ] 
  then
    rm -r embed_custom_train
  fi
  mkdir embed_custom_train
  mkdir embed_custom_train/1792

  if [ -d "exp/chain_cleaned_1d/tdnn1d_sp/output12_custom_train/split_scp" ] 
  then
    rm -r exp/chain_cleaned_1d/tdnn1d_sp/output12_custom_train/split_scp
  fi
  mkdir exp/chain_cleaned_1d/tdnn1d_sp/output12_custom_train/split_scp

  echo "Splitting layer 12 .scp file"
  python3 split_scp.py custom_train

  echo "Parsing alignments"
  python3 parse_ali.py other custom_train
  echo "Stage 6 ending"
  echo ""
fi


# if [ $stage -le 7 ]; then
#   echo "Stage 7 starting"

#   lda_runs=10
#   echo "Sampling .scp file"
#   python3 sample_lda.py $lda_runs

#   for run in $(seq 1 $lda_runs)
#   do
#     echo "Computing LDA for run #$run"
#     $train_cmd embed_custom_train/lda/lda_$run.log \
#       ivector-compute-lda \
#       --verbose=2 \
#       --total-covariance-factor=0.0 \
#       --dim=512 \
#       scp:embed_custom_train/lda/lda_$run.scp \
#       ark:embed_custom_train/utt2spk \
#       embed_custom_train/lda/lda_$run.mat || exit 1;
#   done

#   matrix-sum --average=true \
#     embed_custom_train/lda/lda_1.mat embed_custom_train/lda/lda_2.mat \
#     embed_custom_train/lda/lda_3.mat embed_custom_train/lda/lda_4.mat \
#     embed_custom_train/lda/lda_5.mat embed_custom_train/lda/lda_6.mat \
#     embed_custom_train/lda/lda_7.mat embed_custom_train/lda/lda_8.mat \
#     embed_custom_train/lda/lda_9.mat embed_custom_train/lda/lda_10.mat \
#     embed_custom_train/lda/lda.mat

#   echo "Stage 7 ending"
# fi


# if [ $stage -le 8 ]; then
#   echo "===================="
#   echo "Stage 8 starting"
#   # echo "Applying LDA transformation"
#   if [ -d "embed_custom_train/512" ]
#   then
#     rm -r embed_custom_train/512
#   fi
#   mkdir embed_custom_train/512

#   for dirfile in embed_custom_train/1792/embed*.scp
#   do
#     scp=${dirfile:24:-4}

#     if [ $scp != "embed" ]
#     then
#       transform-vec embed_custom_train/lda/lda.mat \
#         scp:embed_custom_train/1792/$scp.scp \
#         ark,scp:embed_custom_train/512/$scp.ark,embed_custom_train/512/$scp.scp
#     fi
#   done

#   echo "Stage 8 ending"
#   echo ""
# fi


if [ $stage -le 9 ]; then
  echo "===================="
  echo "Stage 9 starting"
  # Preparing training examples
  if [ -d "embed_custom_train/1792/egs" ] 
  then
    rm -r embed_custom_train/1792/egs
  fi
  mkdir embed_custom_train/1792/egs

  if [ -d "embed_custom_train/1792/egs_txt" ] 
  then
    rm -r embed_custom_train/1792/egs_txt
  fi
  mkdir embed_custom_train/1792/egs_txt

  python3 prepare_egs.py custom_train 1792
  echo "Stage 9 ending"
  echo ""
fi

exit 1


if [ $stage -le 10 ]; then
  echo "===================="
  echo "Stage 10 starting"
  # Training TDNN
  if [ ! -d "tdnn_mod" ]
  then
    mkdir tdnn_mod
  fi
  nohup python3 -u tdnn_train.py > tdnn_train.log &
  echo "See main TDNN training log in tdnn_train.log"
  echo ""
fi

echo "train.sh ending"
exit 0
