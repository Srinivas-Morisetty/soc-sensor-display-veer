# TODO & Tracking Checklist

- [x] Analyze `Project_Abstract.docx`, `Architecture_Document.docx`, and `RISC-V_VeeR_EL2_PRM.pdf`
- [x] Align repository structure with `reference architecture`
- [x] Author Architecture & Micro-Architecture Specification (`docs/Architecture_MicroArchitecture_Spec.md`)
- [x] Author Complete Register Map (`docs/Register_Map.md`) and IP Specs
- [x] Create CSV Testplan (`docs/Testplan.csv`) and VIP/Interface Inventory CSVs
- [x] Implement synthesizable RTL (`rtl/`), SV interfaces/SVA, and UVM testbenches (`uvm_tb/`)
- [x] Implement bare-metal RISC-V C/assembly firmware (`firmware/`)
- [ ] Run local Vivado/VCS/Verilator simulations and capture waveform screenshots in `docs/images/`
- [ ] Integrate full CHIPS Alliance `Cores-VeeR-EL2` RTL into `rtl/core/` with 64-to-32-bit AHB-Lite width adapter
- [ ] Push final verified repository to `Srinivas-Morisetty/soc-sensor-display-veer`
