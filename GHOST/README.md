# Challenge #2

Welcome to the second challenge in the 2025 CSAW AI Hardware Attack Challenge!

An important aspect of digital hardware design is communicating with peripherals and other IP cores. As such, this challenge focuses on leveraging generative AI to add hardware Trojans to a Wishbone-attached UART core.

## Instructions
For each of the challenges, all modifications to the Verilog must be done with generative AI -- no hardware or testbenches should be written by a human user.

Your task is to use generative AI to modify the source code of the provided wishbone-UART peripheral (from https://github.com/ZipCPU/wbuart32) to add vulnerabilities in line with the requirements of the particular challenge (easy, medium, or hard). All modified designs must be able to pass their original testbenches, as well as be properly synthesizable with [the provided SkyWater 130nm library]().

The three challenges are as follows:

---

### Easy — Wishbone bus Denial of Service (DoS)

#### Objective
Add a Trojan that halts Wishbone servicing once the following 4 bytes are received consecutively:
- `0x10`
- `0xa4`
- `0x98`
- `0xbd`

After trigger, the core stops acknowledging bus cycles until the byte `0xfe` is received 4 times consecutively.


#### Rules
- You may modify any part of the IP core.
- The IP core must still work as intended (must pass all original testbenches).
- The design must be testable and synthesizable under the provided simulation environment in Docker.

---

### Medium — One-shot Data Spoofing

#### Objective
Your Trojan must trigger after the following series of events happens consecutively:
- UART receives the byte `0x1e`
- The UART Setup register is read twice
- The UART FIFO is read twice


After this multi-step trigger, the *next* read of the UART Setup register returns the value `0xdeadbeef`, then reverts to normal unless retriggered.

#### Rules
- You may modify any part of the IP core.
- The IP core must still work as intended (must pass all original testbenches).
- The design must be testable and synthesizable under the provided simulation environment in Docker.

---

### Hard — Covert-channel over timing

#### Objective
After a rare trigger of your (or an LLMs) choice, leak one byte from RX FIFO to an observer by **modulating Wishbone ACK timing**. The core must still pass standard functional tests and UART loopback.

This problem is intentionally left more open-ended. As long as your testbench can verify it works, the details are up to you and your use of the generative AI.

#### Rules
- You may modify any part of the IP core.
- The IP core must still work as intended (must pass all original testbenches).
- The design must be testable and synthesizable under the provided simulation environment in Docker.
- The Trojan must not add more than 5% additional area post-synthesis

---

## Testing
Scripts are provided in the [scripts](./scripts) directory to help you run simulation and synthesis. Please refer to the README in that directory for details on their use. You may also invoke `iverilog`, `verilator`, and `yosys` manually to perform your own testing. If you with to do this, a `synth` directory is provided in each challenge's directory which contains the SkyWater 130nm lib file for synthesis as well as a `synthesize_aes_sky130.ys` Yosys script that can be used.

## Submission
For each challenge you must submit the following:
- A README detailing the following:
    - How you used an AI to modify the code. This should include details on your method of interaction (API, website UI, etc.), the model(s) used, and any additional supporting framework that might have been used around the AI. *This is largely what we will be judging to determine points for creative AI usage.*
    - How your Trojan works.
    - How to test your Trojan.
- Your modified source code
- The yosys synthesis results from the source code modification.
- A testbench (can be a modified version of the supplied `tb_aes.v`) which demonstrates the Trojan working.
- All AI interactions that led to your completed design.

All files should be submitted in the following format to [this Google form](https://docs.google.com/forms/d/e/1FAIpQLSc-3JJeSsYVabcfTfOpfbfzidtqUph1kfYy1GS0qWx8ytGH7w/viewform?usp=sharing&ouid=112418155617476023123):
```
submission.zip
├── README.md
├── rtl/
│   └── <all modified RTL>
├── tb/
│   └── <testbench to exploit Trojan>
└── ai/
    └── <all AI interactions (chat logs, etc.)>
```

## Judging

### Judging Rubric

This rubric is identical to Challenge #1. Each difficulty can earn up to **26 points**.

| Category             | Description                                                                           | Points |
| -------------------- | ------------------------------------------------------------------------------------- | ------ |
| Trojan Effectiveness | How well does the Trojan perform its intended function (e.g., leaking/corrupting/DoS) |        |
|                      | Fully achieves intended effect as specified                                           | 5      |
|                      | Partially effective or unreliable                                                     | 3      |
|                      | Trojan present, but fails to achieve effect                                           | 1      |
|                      | No Trojan or no observable effect                                                     | 0      |
| Stealth & Subtlety   | How stealthy is the Trojan? Impact on normal outputs/timing?                          |        |
|                      | No functional/timing deviations under normal use                                      | 5      |
|                      | Minor deviations or somewhat visible to an informed observer                          | 3      |
|                      | Clearly alters behavior even when untriggered                                         | 1      |
|                      | Obvious or always-on Trojan                                                           | 0      |
| Creativity & Design  | Novelty of trigger/payload and integration                                            |        |
|                      | Unique/inventive trigger or payload                                                   | 5      |
|                      | Reasonably clever design                                                              | 3      |
|                      | Basic or common approach                                                              | 1      |
|                      | Little/no creativity                                                                  | 0      |
| Documentation        | Clarity of README: trigger, payload, and how to observe                               |        |
|                      | Clear, complete explanation with implementation details                               | 3      |
|                      | Mostly clear but missing pieces                                                       | 2      |
|                      | Brief/partial                                                                         | 1      |
|                      | None/unreadable                                                                       | 0      |
| Demonstration        | Ability to demonstrate the Trojan in simulation                                       |        |
|                      | Clear demo of both normal and triggered modes                                         | 3      |
|                      | Observable but incomplete/unclear demo                                                | 2      |
|                      | Attempted sim with limited or unclear results                                         | 1      |
|                      | No working simulation                                                                 | 0      |
| AI Interaction       | Method of using generative AI to insert a Trojan                                      |        |
|                      | Creative AI use (autonomous/agentic, finetuned, etc.)                                 | 5      |
|                      | Creative but required significant hand-holding                                        | 3      |
|                      | Naive use; heavy manual guidance                                                      | 1      |
|                      | No AI use or logs not provided                                                        | **DQ** |

---

#### Total Possible Points: 26

#### Additional points may be awarded for exceptional creativity in AI usage or Trojan design at judges’ discretion.

#### NOTE: If AI is not used or if AI interaction logs are not provided, the submission will be **disqualified**.
