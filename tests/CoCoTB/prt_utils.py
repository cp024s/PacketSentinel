import random

def random_frame_length(min_val=1, max_val=1518):
    return random.randint(min_val, max_val)

def random_start_value():
    return random.randint(0, 0xFF)

def random_slot():
    return random.randint(0, 1)
