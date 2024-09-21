# Mailbox Design

## CoE

### SDO Read State Machiine

> Ref: IEC 61158-5-12:2019 6.1.4.1.3 SDO Interactions

Repeat requests are not implemented for simplicity.

```mermaid
graph TB;
    send_read_request --> read_mbx;
    read_mbx -->|expedited response| expedited;
    expedited --> success;
    read_mbx -->|normal response| normal;
    normal --> |complete| success;
    normal --> |incomplete| request_segment
    request_segment --> read_mbx_segment;
    read_mbx_segment --> segment;
    segment -->|not more follows| success;
    segment -->|more follows| request_segment; 
```

### SDO Write State Machine

```mermaid
graph TB;
    start --> |fits in expedited| send_expedited_request;
    send_expedited_request --> read_mbx;
    read_mbx --> success
    start --> |fits in normal| send_normal_request;
    send_normal_request --> read_mbx;
    start --> |fits in segmented| send_first_segment;
    send_first_segment --> read_mbx_first_segment;
    read_mbx_first_segment --> send_segment;
    send_segment --> read_mbx_segment;
    read_mbx_segment --> |data remaining| send_segment;
    read_mbx_segment --> |no data remaining| success;


```
