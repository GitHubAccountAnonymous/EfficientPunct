import argparse
from helper import has_letters, has_numbers, list_non_hidden
import json
from parse_raw_data import numbers2words, remove_special
import pickle
import random
import unidecode




parser = argparse.ArgumentParser(description="Parse UniPunc data")
parser.add_argument('set_split', help='train, dev, or test')
set_split = parser.parse_args().set_split




considered_punct = [',', '.', '?']



if set_split == 'train' or set_split == 'dev':
    f = open('dataset_mod/unipunc_data/train-audio.json', 'r')
    train_dev = f.read().split('\n')
    f.close()
    try:
        while True:
            train_dev.remove('')
    except ValueError:
        pass
    train_dev = [json.loads(sample) for sample in train_dev]
    
    idx = list(range(len(train_dev)))
    random.shuffle(idx)
    
    
    ours_dir = list_non_hidden('dataset_mod/unipunc_data/ours')
    if 'train_idx.txt' in ours_dir and 'dev_idx.txt' in ours_dir:
        
        if set_split == 'train':
            f = open('dataset_mod/unipunc_data/ours/train_idx.txt', 'r')
            idx = [int(idx) for idx in f.read()[1:-1].split(',')]
            f.close()
        elif set_split == 'dev':
            f = open('dataset_mod/unipunc_data/ours/dev_idx.txt', 'r')
            idx = [int(idx) for idx in f.read()[1:-1].split(',')]
            f.close()
        
    else:
        # 10% of training data will be used as validation set
        split_idx = int(len(train_dev) * 0.9)
        train_idx = idx[:split_idx]
        dev_idx = idx[split_idx:]
        
        f = open('dataset_mod/unipunc_data/ours/train_idx.txt', 'w')
        f.write(str(train_idx))
        f.close()
        f = open('dataset_mod/unipunc_data/ours/dev_idx.txt', 'w')
        f.write(str(dev_idx))
        f.close()
        
        if set_split == 'train':
            idx = train_idx
        elif set_split == 'dev':
            idx = dev_idx
    
    data = [train_dev[i] for i in idx]

elif set_split == 'test':
    f = open('dataset_mod/unipunc_data/test-audio.json', 'r')
    data = f.read().split('\n')
    f.close()
    try:
        while True:
            data.remove('')
    except ValueError:
        pass
    data = [json.loads(sample) for sample in data]
    
else:
    raise RuntimeError('set_split argument must be train, dev, or test')




if set_split == 'train':
    utt2spk = open('data/custom_train/utt2spk', 'w')
    wav_scp = open('data/custom_train/wav.scp', 'w')
    extract_audio_sh = open('custom_train_extract_audio.sh', 'w')
elif set_split == 'dev' or set_split == 'test':
    utt2spk = open('data/custom_predict/utt2spk', 'w')
    wav_scp = open('data/custom_predict/wav.scp', 'w')
    extract_audio_sh = open('custom_predict_extract_audio.sh', 'w')



count = 0

for i, sample in enumerate(data):
    
    if i % 10000 == 0:
        print('Processing sample', i+1, '/', len(data))
    
    
    # Getting speaker ID: spk
    speaker_id = sample['speaker_id']
    idx = speaker_id.find('.')
    assert idx != -1
    spk = speaker_id[idx+1:]
    
    
    # Getting utterance ID: utt
    uttids = sample['id']
    uttids = uttids.split(',')
    try:
        while True:
            uttids.remove('')
    except ValueError:
        pass
    
    for i in range(len(uttids)):
        idx = uttids[i].find(spk + '_')
        assert idx != -1
        uttids[i] = uttids[i][idx + len(spk) + 1 :]
    
    if len(uttids) == 0:
        raise RuntimeError('len(uttids) is 0')
    elif len(uttids) == 1:
        assert len(uttids[0]) > 0
        utt = uttids[0]
    elif len(uttids) > 1:
        prev = uttids[0]
        for i in range(1, len(uttids)):
            assert uttids[i] == str(int(prev) + 1)
            prev = uttids[i]
        utt = uttids[0] + '-' + uttids[-1]
    utt = spk + '-' + utt
    
    
    # Getting text
    text = sample['tgt_text']
    text = unidecode.unidecode(text)
    # Things in parentheses are not spoken words. They are merely indications
    # of other sound present in the audio.
    while '(' in text and ')' in text:
        left_idx = text.find('(')
        right_idx = text.find(')')
        if right_idx < left_idx:
            text = text[:right_idx] + text[right_idx+1:]
            continue
        
        to_remove = text[left_idx:right_idx+1]
        text = text.replace(to_remove, ' ')
        
    text = remove_special(text, considered_punct)
    if has_numbers(text):
        text = numbers2words(text)
        
    if len(text) == 0:
        count += 1
        continue
    
    last = text[-1]
    if has_numbers(last) or has_letters(last):
        text += '.'
    text = text.strip()
    
    
    # Getting wav extraction command to go into wav.scp
    audio = sample['audio']
    idx = audio.rfind('/')
    assert idx != -1
    audio = audio[idx+1:]
    assert audio.count(':') == 2
    
    first_colon = audio.find(':')
    second_colon = audio.rfind(':')
    assert first_colon != -1
    assert second_colon != -1
    
    start = int(audio[first_colon+1:second_colon])
    dur = int(audio[second_colon+1:])
    sr = 16000
    
    wav_dir = '/home/liuxingyi99/kaldi/egs/tedlium/s5_r3/dataset_mod/mustc1-en-de/data/wav'
    if set_split == 'train':
        sox = 'sox ' + wav_dir + '/' + audio[:first_colon] + \
              ' /home/liuxingyi99/kaldi/egs/tedlium/s5_r3/db/custom_train/' + \
              utt + '.wav trim ' + str(int(start/sr)) + ' ' + str(int(dur/sr)+1)
    elif set_split == 'dev' or set_split == 'test':
        sox = 'sox ' + wav_dir + '/' + audio[:first_colon] + \
              ' /home/liuxingyi99/kaldi/egs/tedlium/s5_r3/db/custom_predict/' + \
              utt + '.wav trim ' + str(int(start/sr)) + ' ' + str(int(dur/sr)+1)
              
    extract_audio_sh.write(sox + '\n')
    
    # Writing to files
    utt2spk.write(utt + ' ' + spk + '\n')
    
    if set_split == 'train':
        wav_scp.write(utt + ' /home/liuxingyi99/kaldi/egs/tedlium/s5_r3/db/custom_train/' + utt + '.wav' + '\n')
        f = open('db/custom_train_text/' + utt + '.txt', 'w')
        f.write(text)
        f.close()
    elif set_split == 'dev' or set_split == 'test':
        wav_scp.write(utt + ' /home/liuxingyi99/kaldi/egs/tedlium/s5_r3/db/custom_predict/' + utt + '.wav' + '\n')
        f = open('db/custom_predict_text/' + utt + '.txt', 'w')
        f.write(text)
        f.close()

utt2spk.close()
wav_scp.close()
extract_audio_sh.close()
    
    
    
    
    