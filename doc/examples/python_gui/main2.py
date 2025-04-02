
import zenoh
import threading
import time

all_keys = {

"s/1/outputs/pdo/0/entry/0/EL2008_Channel_1_Output",
"s/1/outputs/pdo/1/entry/0/EL2008_Channel_2_Output",
"s/1/outputs/pdo/2/entry/0/EL2008_Channel_3_Output",
"s/1/outputs/pdo/3/entry/0/EL2008_Channel_4_Output",
"s/1/outputs/pdo/4/entry/0/EL2008_Channel_5_Output",
"s/1/outputs/pdo/5/entry/0/EL2008_Channel_6_Output",
"s/1/outputs/pdo/6/entry/0/EL2008_Channel_7_Output",
"s/1/outputs/pdo/7/entry/0/EL2008_Channel_8_Output",
"s/3/outputs/pdo/0/entry/1/EL7031-0030_ENC_RxPDO-Map_Control_compact_Enable_latch_extern_on_positive_edge",
"s/3/outputs/pdo/0/entry/2/EL7031-0030_ENC_RxPDO-Map_Control_compact_Set_counter",
"s/3/outputs/pdo/0/entry/3/EL7031-0030_ENC_RxPDO-Map_Control_compact_Enable_latch_extern_on_negative_edge",
"s/3/outputs/pdo/0/entry/6/EL7031-0030_ENC_RxPDO-Map_Control_compact_Set_counter_value",
"s/3/outputs/pdo/1/entry/0/EL7031-0030_STM_RxPDO-Map_Control_Enable",
"s/3/outputs/pdo/1/entry/1/EL7031-0030_STM_RxPDO-Map_Control_Reset",
"s/3/outputs/pdo/1/entry/2/EL7031-0030_STM_RxPDO-Map_Control_Reduce_torque",
"s/3/outputs/pdo/2/entry/0/EL7031-0030_STM_RxPDO-Map_Velocity_Velocity",
"s/5/outputs/pdo/0/entry/0/EL7041_ENC_RxPDO-Map_Control_compact_Enable_latch_C",
"s/5/outputs/pdo/0/entry/1/EL7041_ENC_RxPDO-Map_Control_compact_Enable_latch_extern_on_positive_edge",
"s/5/outputs/pdo/0/entry/2/EL7041_ENC_RxPDO-Map_Control_compact_Set_counter",
"s/5/outputs/pdo/0/entry/3/EL7041_ENC_RxPDO-Map_Control_compact_Enable_latch_extern_on_negative_edge",
"s/5/outputs/pdo/0/entry/6/EL7041_ENC_RxPDO-Map_Control_compact_Set_counter_value",
"s/5/outputs/pdo/1/entry/0/EL7041_STM_RxPDO-Map_Control_Enable",
"s/5/outputs/pdo/1/entry/1/EL7041_STM_RxPDO-Map_Control_Reset",
"s/5/outputs/pdo/1/entry/2/EL7041_STM_RxPDO-Map_Control_Reduce_torque",
"s/5/outputs/pdo/2/entry/0/EL7041_STM_RxPDO-Map_Velocity_Velocity",
}

def thread1():
    config = zenoh.Config()
    print("Thread 1 Opening session...")
    with zenoh.open(config) as session:
        def listener(sample: zenoh.Sample):
            # print(f"Thread 1 Got {str(sample.key_expr)}")
            if str(sample.key_expr) not in all_keys:
                print("got non-subscribed key!")
        for key in all_keys:
            session.declare_subscriber(key, listener)
        while True:
            time.sleep(1)

def thread2():
    config = zenoh.Config()
    print("Thread 2 Opening session...")
    with zenoh.open(config) as session:
        while True:
            for key in all_keys:
                session.put(key, b"Hello World!")
            time.sleep(0.05)

def thread3():
    config = zenoh.Config()
    print("Thread 3 Opening session...")
    with zenoh.open(config) as session:
        def listener(sample: zenoh.Sample):
            if str(sample.key_expr) not in all_keys:
                print(f"thread 3: got non-subscribed key: {str(sample.key_expr)}")
        for key in all_keys:
            session.declare_subscriber("**/EL7031$*", listener)
        while True:
            time.sleep(1)
            put_key1 = "s/3/outputs/pdo/0/entry/6/EL7031-0030_ENC_RxPDO-Map_Control_compact_Set_counter_value"
            assert put_key1 in all_keys
            put_key2 = "s/3/outputs/pdo/0/entry/2/EL7031-0030_ENC_RxPDO-Map_Control_compact_Set_counter"
            assert put_key2 in all_keys
            session.put(put_key1, "hello from thread 3!")
            session.put(put_key2, "hello from thread 3!")

if __name__ == "__main__":
    t1 = threading.Thread(target=thread1)
    t2 = threading.Thread(target=thread2)
    t3 = threading.Thread(target=thread3)
    t1.start()
    t2.start()
    t3.start()
    t1.join()
    t2.join()
    t3.join()