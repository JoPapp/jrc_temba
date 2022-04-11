MODELRUNS = ["RD_Low"]#, "RD_High", "NP_Low", "NP_High"]

rule all:
    # input: ["results/{model_run}.pickle".format(model_run=model_run) for model_run in MODELRUNS]
    # input: ["results/export_{model_run}".format(model_run=model_run) for model_run in MODELRUNS]
    # input: expand("results/{model_run}_cbc.txt", model_run=MODELRUNS)
    input: expand("results/{model_run}/AnnualEmissions.csv", model_run=MODELRUNS)

rule generate_model_file:
    input: 
        "input_data/{model_run}.xlsx"
    output: 
        "output_data/{model_run}.txt"
    threads: 
        2
    shell:
        "python scripts/excel_to_osemosys.py {input} {output}"

rule modify_model_file:
    input:  
        "output_data/{model_run}.txt"
    output: 
        "output_data/{model_run}_modex.txt"
    threads: 
        2
    shell:
        "python scripts/CBC_results_AS_MODEX.py {input} && cat {input} > {output}"

rule generate_lp_file:
    input: 
        "output_data/{model_run}_modex.txt"
    output: 
        "output_data/{model_run}.lp.gz"
    log: 
        "output_data/glpsol_{model_run}.log"
    threads: 
        1
    shell:
        "glpsol -m model/Temba_0406_modex.txt -d {input} --wlp {output} --check --log {log}"

rule solve_lp:
    input: 
        "output_data/{model_run}.lp.gz"
    output: 
        "output_data/{model_run}.sol"
    log: 
        "output_data/gurobi_{model_run}.log"
    threads: 
        2
    shell:
        'cplex -c "read {input}" "optimize" "write {output}"'

rule remove_zero_values:
    input: "output_data/{model_run}.sol"
    output: "results/{model_run}.sol"
    shell:
        "sed '/ * 0$/d' {input} > {output}"
        
rule transform_results:
    input: "results/{model_run}.sol"
    output: "results/{model_run}_transform.txt"
    shell:
        "Python scripts/transform_31072013.py {input} {output}"
        
rule sort_results:
    input: "results/{model_run}_transform.txt"
    output: "results/{model_run}_sorted.txt"
    shell:
        "sort < {input} > {output}"
        
rule cplex_to_cbc:
    input: "results/{model_run}_sorted.txt"
    output: "results/{model_run}_cbc.txt"
    shell:
        "python scripts/cplextocbc.py {input} {output}"

rule generate_results:
    input: 
        results="results/{model_run}_cbc.txt",
        datafile="output_data/{model_run}_modex.txt"
    params:
        scenario="{model_run}", folder="results/{model_run}"
    output: 
        emissions="results/{model_run}/AnnualEmissions.csv"
    script:
        "scripts/generate_results.py"
