# Challenge #1
Welcome to the first challenge in the 2025 CSAW AI Hardware Attack Challenge!

The first challenges will focus on leveraging generative AI to add hardware Trojans to an AES core. Three difficulties of challenge will be provided: easy, medium, and hard, with each worth increasing points.

## Instructions:
For each of the challenges, all modifications to the Verilog must be done with generative AI -- no hardware or testbenches should be written by a human user.

Your task is to use generative AI to modify the source code of the provided AES core (from https://github.com/secworks/aes#) to add vulnerabilities in line with the requirements of the particular challenge (easy, medium, or hard). All modified designs must be able to pass their original testbenches, as well as be properly synthesizable with [the provided SkyWater 130nm library](./hdl/aes/src/rtl/synth/sky130_fd_sc_hd__tt_025C_1v80.lib).

The three challenges are as follows:

---

### Easy - Basic Key Leakage Trojan
#### Objective:
Modify the AES design to insert a hardware Trojan that leaks part or all of the secret key through any mechanism of your choice.

#### Rules:
- You may modify any part of the AES design.
- Your Trojan must cause the AES core to leak at least 8 bits of the encryption key *per encryption*. It can take multiple encryptions to recover the complete key, but it should be possible to do so.
- You may use any form of direct (simulateable) output for the leakage. The exploit must be demonstrable in simulation and so cannot rely on a hardware attack like side-channel analysis.
- Your Trojan may be always active, or use a simple trigger (e.g., time-based or input value).
- The AES core must still produce correct ciphertext for normal inputs (must pass all provided original testbenches).
- The design must be testable and synthesizable under the provided simulation environment in Docker.

---

### Medium - Last-input Trojan
#### Objective:
Modify the AES design to insert a hardware Trojan for encryption that gives the previous plaintext input as the current ciphertext when given the key: `0xdeadbeef0123456789abcdef0a1b2c3d`.


#### Rules:
- You may modify any part of the AES design.
- You must modify at least two modules for your Trojan, to force the LLM to try to hide malicious logic by spreading it out.
- The Trojan logic must be obfuscated in some manner to attempt to hide the logic from manual code reviewers.
- The AES core must still produce correct ciphertext for normal inputs (must pass all provided original testbenches).
- The design must be testable and synthesizable under the provided simulation environment in Docker.

---

### Hard - Netlist-level Leakage Trojan
#### Objective:
Insert a hardware Trojan into a flattened Verilog netlist of the AES core. The Trojan must leak the lower 8 bits of the encryption key (`key[7:0]`), one bit per encryption, using the LSB of the ciphertext output.

#### Rules:
- You may only modify the flattened netlist provided in the source code.
- You may insert any needed additional logic.
- The AES core must still produce correct ciphertext when the Trojan is not intended to leak the key (must pass all provided original testbenches).
- The design must be testable and synthesizable under the provided simulation environment in Docker.

#### Note: The testbench for simulating the post-synthesis AES core will likely take hours to run. Please make sure you allot time to verify your design passes this.

---

## Testing:
Scripts are provided in the [scripts](./scripts) directory to help you run simulation and synthesis. Please refer to the README in that directory for details on their use. You may also invoke `iverilog` and `yosys` manually to perform your own testing. If you with to do this, a `synth` directory is provided in each challenge's directory which contains the SkyWater 130nm lib file for synthesis as well as a `synthesize_aes_sky130.ys` Yosys script that can be used.

## Submission:
For each challenge you must submit the following:
- A README detailing the following:
    - How you used an AI to modify the code. This should include details on your method of interaction (API, website UI, etc.), the model(s) used, and any additional supporting framework that might have been used around the AI. *This is largely what we will be judging to determine points for creative AI usage.*
    - How your Trojan works.
    - How to test your Trojan.
- Your modified source code
- The yosys synthesis results from the source code modification.
- A testbench (can be a modified version of the supplied `tb_aes.v`) which demonstrates the Trojan working.
- All AI interactions that led to your completed design.

All files should be submitted in the following format to [this Google form](https://docs.google.com/forms/d/e/1FAIpQLScjtTGe0ohFQnBYmQRbA5LSPrlJX0oqDpKnqnS_9ISAuajSAA/viewform?usp=header):
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


## Judging:
### Judging Rubric

This rubric will be used for all three difficulties of challenge. You may submit each challenge for your team to earn a total of 78 points.

Each submission will be scored based on the following criteria. Judges will award points based on which level of success was achieved in each category. Partial levels are not cumulative — select **one level per category**.

| Category               | Description                                                                                   | Points |
|------------------------|-----------------------------------------------------------------------------------------------|--------|
| Trojan Effectiveness | How well does the Trojan perform its intended function (e.g., leaking data)?                 |        |
|                        | Fully leaks the targeted data as specified                                                 | 5      |
|                        | Partially leaks key/data or leaks unreliably                                               | 3      |
|                        | Trojan present, but fails to leak effectively                                              | 1      |
|                        | No Trojan or no observable effect                                                          | 0      |
| Stealth & Subtlety  | How stealthy is the Trojan? Does it alter normal behavior or timing?                         |        |
|                        | No functional/timing deviations under normal use                                           | 5      |
|                        | Minor changes in output, or partially visible to an informed observer                     | 3      |
|                        | Clearly alters output or behavior even when untriggered                                   | 1      |
|                        | Obvious or always-on Trojan                                                               | 0      |
| Creativity & Design | How novel or clever is the Trojan’s trigger or implementation strategy?                      |        |
|                        | Unique or inventive trigger/payload logic                                                  | 5      |
|                        | Reasonably clever design with thoughtful integration                                       | 3      |
|                        | Basic or common approach                                                                   | 1      |
|                        | Little or no creative implementation                                                       | 0      |
| Documentation       | Clarity of README: explains trigger, payload, and how to observe the Trojan                  |        |
|                        | Clearly explains trigger, payload, and implementation details                             | 3      |
|                        | Mostly explains the Trojan but lacks some clarity or completeness                         | 2      |
|                        | Briefly mentions design or only partly helpful                                             | 1      |
|                        | No README or unreadable                                                                   | 0      |
| Demonstration       | Ability to demonstrate the Trojan working in simulation                                       |        |
|                        | Simulation clearly shows both normal and triggered behavior                               | 3      |
|                        | Trojan behavior is observable, but demonstration lacks clarity or completeness            | 2      |
|                        | Attempted simulation with limited or unclear results                                       | 1      |
|                        | No working simulation                                                                      | 0      |
| AI Interaction | Method of using generative AI to insert a Trojan                  |        |
|                        | AI used in a creative manner (fully-autonomous, agentic framework, finetuned LLM, etc.)  | 5      |
|                        | AI used creatively, but required significant human hand-holding/direct interaction       | 3      |
|                        | AI used naively, requiring significant user guidance throughout                          | 1      |
|                        | No AI use or AI interactions not given                                                   | **DQ**   |

---

#### Total Possible Points: 26

#### Additional points may be awarded to outstanding submissions which excel in creative AI usage or Trojan design, to be awarded by the judges discretion.

#### NOTE: If AI is not used or if the logs for interaction with the AI are not provided in the submission, the submission will be disqualified.

