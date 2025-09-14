`include "uvm_macros.svh"
import uvm_pkg::*;
`include "dff.sv"


class dff_config extends uvm_object;

    `uvm_object_utils(dff_config)

    uvm_active_passive_enum agent_type = UVM_ACTIVE;   ///driver and monitor are active ------- passive----> only monitor

    function new(string name = "dff_config");
        super.new(name);

    endfunction
    endclass
    



/////////////////////////////////////////////
class transaction extends uvm_sequence_item;

     `uvm_object_utils(transaction)

    rand bit  rst, d;
    bit      q;

    function new(string name = "transaction");
        super.new(name);
    endfunction


endclass
////////////////////////////////////////////////////

class dff_valid extends uvm_sequence#(transaction);

    `uvm_object_utils(dff_valid)

    function new(string name = "dff_valid");
        super.new(name);
    endfunction

    transaction tr;
 
    virtual task body();
        tr = transaction::type_id::create("tr");
        repeat (15) begin
            start_item(tr);
            assert(tr.randomize());
            tr.rst = 1'b0;
            `uvm_info("SEQ1", $sformatf("rst : %0d d : %0d q : %0d", tr.rst, tr.d, tr.q), UVM_NONE);
            finish_item(tr);
        end
    endtask

endclass


/*******************************/


class dff_invalid extends uvm_sequence#(transaction);

    `uvm_object_utils(dff_invalid)

    function new(string name = "dff_invalid");
        super.new(name);
    endfunction

    transaction tr;
 
    virtual task body();
        tr = transaction::type_id::create("tr");
        repeat (15) begin
            start_item(tr);
            assert(tr.randomize());
            tr.rst = 1'b1;
            `uvm_info("SEQ2", $sformatf("rst : %0d d : %0d q : %0d", tr.rst, tr.d, tr.q), UVM_NONE);
            finish_item(tr);
        end
    endtask

endclass

/*******************************/


class dff_rand_rst_d extends uvm_sequence#(transaction);

    `uvm_object_utils(dff_rand_rst_d)

    function new(string name = "dff_rand_rst_d");
        super.new(name);
    endfunction

    transaction tr;
 
    virtual task body();
        tr = transaction::type_id::create("tr");
        repeat (15) begin
            start_item(tr);
            assert(tr.randomize());
            `uvm_info("SEQ3", $sformatf("rst : %0d d : %0d q : %0d", tr.rst, tr.d, tr.q), UVM_NONE);
            finish_item(tr);
        end
    endtask

endclass

////////////////////////////////////////////////////

class dff_driver extends uvm_driver#(transaction);

    `uvm_component_utils(dff_driver)

    function new(string name = "dff_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    transaction tr;
    virtual dff_if dif;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
        if (!uvm_config_db#(virtual dff_if)::get(this, "", "dif", dif))
            `uvm_error("DRV", "cant get the interface");
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            seq_item_port.get_next_item(tr);
            dif.rst <= tr.rst;
            dif.d <= tr.d;
            `uvm_info("DRV", $sformatf("DUT rst : %0d DUT d : %d q : %d", tr.rst, tr.d, tr.q), UVM_NONE);
            seq_item_port.item_done();
            repeat(2) @(posedge dif.clk);
        end
    endtask

endclass


////////////////////////////////////////////////////
class dff_monitor extends uvm_monitor;

    `uvm_component_utils(dff_monitor)

    uvm_analysis_port#(transaction) send;

    function new(string name = "dff_monitor", uvm_component parent = null);
        super.new(name, parent);
        send = new("send", this);
    endfunction

    transaction tr;
    virtual dff_if dif;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
        if (!uvm_config_db#(virtual dff_if)::get(this, "", "dif", dif))
            `uvm_error("MON", "cant get the interface");
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            repeat(2) @(posedge dif.clk);
           tr.rst = dif.rst;
            tr.d = dif.d;
            tr.q = dif.q;
            `uvm_info("MON", $sformatf("Data sent to scoreboard rst : %0d  d : %d  q : %d",tr.rst, tr.d, tr.q), UVM_NONE);
            send.write(tr);
        end
    endtask

endclass
////////////////////////////////////////////////////


class dff_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(dff_scoreboard)

    uvm_analysis_imp#(transaction, dff_scoreboard) recv;
    transaction tr;

    function new(string name = "dff_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        recv = new("recv", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
    endfunction

      virtual function void write(transaction tr);
    `uvm_info("SCO", $sformatf("rst : %0b  d : %0b  q : %0b", tr.rst, tr.d, tr.q), UVM_NONE);
    if(tr.rst == 1'b1)
      `uvm_info("SCO", "DFF Reset", UVM_NONE)
    else if(tr.rst == 1'b0 && (tr.d == tr.q))
      `uvm_info("SCO", "TEST PASSED", UVM_NONE)
    else
      `uvm_info("SCO", "TEST FAILED", UVM_NONE)
      
          
    $display("----------------------------------------------------------------");
    endfunction

endclass


//////////////////////////////////////////////////////////////

class dff_agent extends uvm_agent;

    `uvm_component_utils(dff_agent)

    dff_driver drv;
    dff_monitor mon;
    uvm_sequencer#(transaction) seqr;
    dff_config cfg;

    function new(string name = "dff_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = dff_monitor::type_id::create("mon", this);
        cfg = dff_config::type_id::create("cfg");

        if (!uvm_config_db#(dff_config)::get(this, "", "cfg", cfg))
            `uvm_error("AGNT", "Cannot get configuration object from the test");
        if(cfg.agent_type == UVM_ACTIVE) begin
            drv = dff_driver::type_id::create("drv", this);
            seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);

            end
    endfunction
 
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction

endclass

////////////////////////////////////////////////////////////

class dff_env extends uvm_env;

    `uvm_component_utils(dff_env)

    dff_agent agnt;
    dff_scoreboard so;
    dff_config cfg;


    function new(string name = "dff_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agnt = dff_agent::type_id::create("agnt", this);
        so = dff_scoreboard::type_id::create("so", this);
        cfg = dff_config::type_id::create("cfg");

        uvm_config_db#(dff_config)::set(this , "agnt", "cfg", cfg);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agnt.mon.send.connect(so.recv);
    endfunction

endclass

////////////////////////////////////////////////////////////

class dff_test extends uvm_test;

    `uvm_component_utils(dff_test)

    dff_env env;
    dff_valid seq1;
    dff_invalid seq2;
    dff_rand_rst_d seq3;

    function new(string name = "dff_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = dff_env::type_id::create("env", this);
        seq1 = dff_valid::type_id::create("seq1", this);
        seq2 = dff_invalid::type_id::create("seq2", this);
        seq3 = dff_rand_rst_d::type_id::create("seq3", this);

    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this);
        seq2.start(env.agnt.seqr);
        #40;
        seq1.start(env.agnt.seqr);
        #40;
        seq3.start(env.agnt.seqr);
        #40;
        phase.drop_objection(this);
    endtask

endclass
////////////////////////////////////////////////////////////
module dff_tb;
    dff_if dif();
    dff dut (
        .rst(dif.rst),
        .d(dif.d),
        .q(dif.q),
        .clk(dif.clk)
    );

    initial begin
        dif.clk = 0;
        forever #10 dif.clk = ~dif.clk;
    end

    initial begin
        uvm_config_db#(virtual dff_if)::set(null, "*", "dif", dif);
        run_test("dff_test");
    end
endmodule