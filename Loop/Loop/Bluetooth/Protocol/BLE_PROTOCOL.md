# FlyingDiabetic BLE Protocol

Protocol version: **1**

This document defines the Bluetooth Low Energy protocol used between the
modified Loop iOS application and the FlyingDiabetic ESP32 display.

The protocol currently provides:

- Current glucose
- Glucose trend
- Glucose delta
- Insulin on board (IOB)
- Carbohydrates on board (COB)
- Loop eventual predicted glucose
- Closed Loop / dosing state
- Glucose timestamp
- iPhone battery level
- Historical glucose graph data
- Loop prediction curve

---

# 1. BLE Architecture

The iPhone acts as the BLE peripheral.

The ESP32 acts as the BLE central.

The Loop BLE service exposes two characteristics:

1. LiveData
2. GlucoseGraph

Both characteristics support:

- Read
- Notify

The ESP32 should normally subscribe to both characteristics.

---

# 2. UUIDs

The UUID values must match the values defined in `BLEUUIDs.swift`.

Service:

    Loop Live Data Service

Characteristics:

    LiveData
    GlucoseGraph

The ESP32 implementation should use the exact UUID strings from the
current Loop implementation.

---

# 3. Byte Order

All multi-byte integer values use:

    Little-endian byte order

Examples:

    UInt16 147
    = 0x0093
    = 93 00

    Int16 -35
    = 0xFFDD
    = DD FF

    UInt32 timestamp
    = least-significant byte first

Signed integers use two's-complement representation.

---

# 4. LiveData Characteristic

Packet type:

    0x01

Current packet length:

    18 bytes

A new LiveData notification is normally generated when a new glucose
reading is received.

Other values such as IOB, COB and prediction are cached and included in
the next glucose-triggered packet.

A newly subscribed client may receive the current snapshot immediately.

---

# 5. LiveData Packet Layout

| Byte(s) | Size | Type   | Description |
|---------|-----:|--------|-------------|
| 0       | 1 | UInt8  | Protocol version |
| 1       | 1 | UInt8  | Packet type |
| 2       | 1 | UInt8  | Flags |
| 3-4     | 2 | UInt16 | Current glucose, mg/dL |
| 5       | 1 | UInt8  | Glucose trend |
| 6       | 1 | Int8   | Glucose delta, mg/dL |
| 7-8     | 2 | Int16  | IOB × 100 |
| 9-10    | 2 | UInt16 | COB, grams |
| 11-12   | 2 | UInt16 | Eventual predicted glucose, mg/dL |
| 13-16   | 4 | UInt32 | Glucose Unix timestamp |
| 17      | 1 | UInt8  | iPhone battery percentage |

---

# 6. Protocol Version

Byte 0:

    0x01 = Protocol version 1

The current protocol uses version 1.

Clients should ignore trailing bytes they do not understand when a
packet contains more data than expected.

---

# 7. Packet Type

Byte 1:

    0x01 = LiveData
    0x02 = GlucoseGraph

The graph notification transport also identifies graph chunks as
message type `0x02`.

---

# 8. Flags

Byte 2 is a bit field.

Currently:

    Bit 0 = Loop dosing enabled

Values:

    0 = dosing disabled
    1 = dosing enabled

Bits 1-7 are currently reserved.

Clients must ignore unknown/reserved flag bits.

Example:

    01

means:

    00000001

therefore Loop dosing is enabled.

---

# 9. Current Glucose

Bytes:

    3-4

Type:

    UInt16 little-endian

Unit:

    mg/dL

Example:

    73 00

    0x0073 = 115

Result:

    115 mg/dL

---

# 10. Trend

Byte:

    5

Type:

    UInt8

The value represents the Loop/CGM trend mapping used by the
FlyingDiabetic protocol.

The ESP32 should map this value to the appropriate trend arrow.

The mapping must remain synchronized with the `LoopLiveData.Trend`
definition in the Loop project.

---

# 11. Delta

Byte:

    6

Type:

    Int8

Unit:

    mg/dL

Examples:

    01 = +1 mg/dL
    00 =  0 mg/dL
    FF = -1 mg/dL
    FD = -3 mg/dL

Reserved value:

    -128 / 0x80 = unknown delta

Valid transmitted delta range:

    -127 ... +127

---

# 12. Insulin On Board

Bytes:

    7-8

Type:

    Int16 little-endian

Unit:

    hundredths of an insulin unit

To decode:

    IOB = rawValue / 100.0

Examples:

    8E 00
    = 142
    = 1.42 U

Negative IOB values are valid.

Example:

    DD FF
    = -35
    = -0.35 U

The ESP32 must decode IOB as a signed `int16_t`, not `uint16_t`.

---

# 13. Carbohydrates On Board

Bytes:

    9-10

Type:

    UInt16 little-endian

Unit:

    grams

Example:

    10 00
    = 16 g

---

# 14. Eventual Predicted Glucose

Bytes:

    11-12

Type:

    UInt16 little-endian

Unit:

    mg/dL

This is the final point of Loop's:

    predictedGlucoseIncludingPendingInsulin

prediction curve.

It therefore represents Loop's eventual predicted glucose including
pending insulin.

Example:

    6D 00
    = 109 mg/dL

---

# 15. Timestamp

Bytes:

    13-16

Type:

    UInt32 little-endian

The timestamp is Unix time in seconds.

It represents the timestamp of the glucose sample, not the time at
which the BLE notification happened.

This distinction is important when determining glucose age.

---

# 16. iPhone Battery

Byte:

    17

Type:

    UInt8

Values:

    0 ... 100 = battery percentage
    255        = unavailable

Example:

    5F
    = 95%

The value comes from the public iOS battery API and may be quantized by
iOS rather than representing exact 1% increments.

---

# 17. LiveData Example

Packet:

    01 01 01 73 00 04 00 79 00 0E 00 6D 00 71 9D 7D 6A 64

Decode:

    Protocol:       1
    Packet type:    LiveData
    Dosing enabled: Yes
    Glucose:        115 mg/dL
    Trend:          4
    Delta:          0 mg/dL
    IOB:            1.21 U
    COB:            14 g
    Prediction:     109 mg/dL
    Timestamp:      0x6A7D9D71
    iPhone battery: 100%

---

# 18. GlucoseGraph Characteristic

The graph characteristic provides:

- Up to 20 actual historical glucose readings
- Loop's predicted glucose curve

Historical samples come from Loop's stored glucose data.

The newest 20 actual samples are used.

Missing CGM samples are not synthesized.

---

# 19. GlucoseGraph Payload

Before BLE transport chunking, the graph payload has this format:

| Byte(s) | Size | Type | Description |
|---------|-----:|------|-------------|
| 0 | 1 | UInt8 | Protocol version |
| 1 | 1 | UInt8 | Packet type = 2 |
| 2 | 1 | UInt8 | Historical point count |
| 3 | 1 | UInt8 | Prediction point count |
| 4... | variable | Points | Historical points followed by prediction points |

Every graph point occupies exactly:

    4 bytes

Format:

| Offset | Size | Type | Description |
|--------|-----:|------|-------------|
| 0-1 | 2 | UInt16 | Glucose, mg/dL |
| 2-3 | 2 | Int16 | Relative time, minutes |

---

# 20. Relative Graph Time

All graph timestamps are expressed relative to the current/latest
glucose sample.

Therefore:

    0 = current glucose timestamp

Historical values have negative relative times:

    -5
    -10
    -15
    ...

Prediction values have positive relative times:

    +1
    +6
    +11
    ...

Prediction points with a relative time <= 0 are filtered out before
the graph packet is generated.

This creates a clean graph boundary:

    history ---- current glucose ---- prediction
                    0 min

---

# 21. Historical Graph Data

The iOS application queries a larger historical window and takes:

    newest 20 valid stored glucose samples

The protocol does not assume that readings occur exactly every five
minutes.

For example:

    176 mg/dL @ -104 min
    180 mg/dL @ -100 min
    ...
    148 mg/dL @ -5 min
    147 mg/dL @ 0 min

If fewer than 20 valid samples are available, fewer samples are sent.

No artificial values should be generated to fill gaps.

---

# 22. Prediction Graph Data

Prediction data comes from:

    predictedGlucoseIncludingPendingInsulin

Each prediction point contains:

    glucose value
    timestamp

The timestamp is converted into minutes relative to the latest real
glucose timestamp.

Only points with:

    relativeMinutes > 0

are included.

The number of prediction points is variable.

For example:

    History:    20 points
    Prediction: 74 points

The ESP32 must therefore use the point counts contained in the packet
rather than assuming fixed array lengths.

---

# 23. Graph Notification Transport

Because a complete graph can exceed the BLE notification size, the
encoded GlucoseGraph payload is transported using chunks.

Each graph notification has a five-byte transport header:

| Byte | Type | Description |
|------|------|-------------|
| 0 | UInt8 | Transport version |
| 1 | UInt8 | Message type |
| 2 | UInt8 | Sequence ID |
| 3 | UInt8 | Chunk index |
| 4 | UInt8 | Total chunk count |
| 5... | Data | Graph payload fragment |

Current values:

    Transport version = 1
    Message type      = 2

---

# 24. Sequence ID

All chunks belonging to the same graph snapshot have the same sequence
ID.

Example:

    01 02 07 00 03 ...
    01 02 07 01 03 ...
    01 02 07 02 03 ...

means:

    Sequence 7
    Chunk 0 of 3
    Chunk 1 of 3
    Chunk 2 of 3

The sequence ID is UInt8 and may wrap from:

    255 -> 0

The receiver must support this wraparound.

---

# 25. Chunk Reassembly

The ESP32 should:

1. Read the transport header.
2. Check transport version.
3. Check message type.
4. Read the sequence ID.
5. Start a new graph buffer when a new sequence is detected.
6. Store fragments according to their chunk index.
7. Wait until all `totalChunks` fragments have arrived.
8. Concatenate the payload fragments in chunk-index order.
9. Decode the resulting GlucoseGraph payload.
10. Replace the currently displayed graph only after the complete new
    graph has been decoded successfully.

An incomplete graph should never replace the previous valid graph.

---

# 26. Single-Chunk Graphs

If the negotiated BLE update size is large enough, the entire graph may
fit into one notification.

Example transport header:

    01 02 00 00 01

Decode:

    Transport version: 1
    Message type:      Graph
    Sequence ID:       0
    Chunk index:       0
    Total chunks:      1

The GlucoseGraph payload begins immediately at byte 5.

For example:

    01 02 00 00 01 | 01 02 14 4A ...

The part before `|` is the transport header.

The part after `|` is the actual graph payload:

    01 = protocol version
    02 = graph packet
    14 = 20 historical points
    4A = 74 prediction points

---

# 27. BLE MTU / Chunk Size

The iOS application determines the available notification size from:

    CBCentral.maximumUpdateValueLength

The graph transport dynamically chooses the fragment size.

The ESP32 must therefore NOT assume a fixed BLE chunk length.

Only the five-byte transport header has a fixed size.

---

# 28. Notification Behaviour

LiveData:

    New glucose
        -> update glucose/trend/delta/timestamp
        -> use latest cached IOB/COB/prediction/dosing/battery
        -> send one LiveData notification

Other Loop state changes:

    IOB
    COB
    prediction
    dosing state

are cached and do not independently trigger LiveData notifications.

GlucoseGraph:

    New glucose
        -> fetch historical glucose
        -> combine with latest prediction
        -> build graph snapshot
        -> send graph chunk sequence

A newly subscribed client may also receive the current cached snapshot.

---

# 29. Unknown / Invalid Values

Current reserved values:

    Delta:
        0x80 / -128 = unknown

    Phone battery:
        0xFF / 255 = unavailable

Clients should gracefully handle unknown values rather than displaying
them as real measurements.

---

# 30. ESP32 Decoder Requirements

The ESP32 implementation must:

- Decode all multi-byte fields as little-endian.
- Treat IOB as signed Int16.
- Treat delta as signed Int8.
- Respect variable history and prediction counts.
- Support graph chunk reassembly.
- Support sequence-ID wraparound.
- Never assume a fixed BLE MTU.
- Ignore unknown trailing LiveData bytes.
- Ignore reserved flag bits.
- Keep the last valid graph if a new graph transfer is incomplete.
- Use the glucose timestamp to determine glucose age.
