# SCCPU & PLCPU

RISC-V RV32I CPU 设计与实现，包含单周期 CPU（SCCPU）、五级流水线 CPU（PLCPU）以及 FPGA SoC 上板工程。

## 项目结构

```
├── sccpu_sim/          # 单周期 CPU ModelSim 仿真
├── plcpu_sim/          # 流水线 CPU ModelSim 仿真
└── vivado_sccpu_soc/   # Vivado FPGA 工程（Nexys4DDR）
    ├── rtl/            # Verilog 源码
    ├── program/        # 汇编程序与 COE 初始化文件
    └── constraints/    # 引脚约束
```

## 功能简介

- **SCCPU**：单周期 RISC-V 处理器，支持 RV32I 指令集
- **PLCPU**：五级流水线（IF → ID → EX → MEM → WB），含 load-use 阻塞与数据旁路
- **FPGA SoC**：将 SCCPU 集成到 Nexys4DDR 开发板，可通过拨码开关与七段数码管交互

## 仿真

使用 ModelSim 打开对应工程文件：

- 单周期：`sccpu_sim/project/SCCPU_SIM.mpf`
- 流水线：`plcpu_sim/project/PLCPU_SIM.mpf`

## FPGA 上板

使用 Vivado 打开 `vivado_sccpu_soc` 目录下的工程，目标板卡为 **Digilent Nexys4 DDR**。

## 许可证

仅供学习交流使用。
