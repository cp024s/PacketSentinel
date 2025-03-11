class Coverage:
    def __init__(self):
        self.frame_sizes = []
        self.slot_usage = []

    def record_frame_size(self, size):
        self.frame_sizes.append(size)

    def record_slot_usage(self, slot):
        self.slot_usage.append(slot)

    def report(self):
        unique_sizes = sorted(set(self.frame_sizes))
        unique_slots = sorted(set(self.slot_usage))
        print("---------- COVERAGE REPORT ----------")
        print(f"Frame sizes tested: {unique_sizes}")
        print(f"Slots used: {unique_slots}")
        print("-------------------------------------")
