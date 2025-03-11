class Scoreboard:
    def __init__(self):
        # expected_data is a dictionary with slot number as key and list of expected bytes as value.
        self.expected_data = {}

    def store_frame(self, slot, data):
        self.expected_data[slot] = data

    def invalidate_frame(self, slot):
        if slot in self.expected_data:
            del self.expected_data[slot]

    def has_frame(self, slot):
        return slot in self.expected_data

    def get_frame_length(self, slot):
        if slot in self.expected_data:
            return len(self.expected_data[slot])
        return 0

    def check_frame(self, slot, received_data):
        expected = self.expected_data.get(slot, [])
        if expected == received_data:
            print(f"[SCOREBOARD] Slot {slot} PASSED: Received data matches expected.")
        else:
            print(f"[SCOREBOARD] Slot {slot} FAILED: Expected {expected}, got {received_data}")
