# from workflow.scripts.utils.utils import get_mem_mb

################################################################################
# StrandPhaseR things                                                          #
################################################################################


rule convert_strandphaser_input:
    """
    rule fct: extract only segmentation with WC orientation 
    input: initial_strand_state file coming from rule segmentation_selection & info file from mosaic count output
    output: filtered TSV file with start/end coordinates of WC-orientated segment to be used by strandphaser
    """
    input:
        states="{folder}/{sample}/segmentation/Selection_initial_strand_state",
        info="{folder}/{sample}/counts/{sample}.info",
    output:
        "{folder}/{sample}/strandphaser/strandphaser_input.txt",
    log:
        "{folder}/log/strandphaser/convert_strandphaser_input/{sample}.log",
    conda:
        "../envs/rtools.yaml"
    script:
        "../scripts/strandphaser_scripts/helper.convert_strandphaser_input.R"




rule check_single_paired_end:
    input:
        bam=lambda wc: expand(
            "{folder}/{sample}/bam/{cell}.sort.mdup.bam",
            folder=config["data_location"],
            sample=wc.sample,
            cell=bam_per_sample_local[str(wc.sample)],
        ),
    output:
        single_paired_end_detect="{folder}/{sample}/config/single_paired_end_detection.txt",
    log:
        "{folder}/log/config/{sample}/single_paired_end.log",
    conda:
        "../envs/mc_base.yaml"
    script:
        "../scripts/utils/detect_single_paired_end.py"


# TODO : replace by clean config file if possible or by temporary removed file
rule prepare_strandphaser_config_per_chrom:
    """
    rule fct: prepare config file used by strandphaser
    input: input used only for wildcards : sample, window & bpdens
    output: config file used by strandphaser
    """
    input:
        seg_initial_str_state="{folder}/{sample}/segmentation/Selection_initial_strand_state",
        single_paired_end_detect="{folder}/{sample}/config/single_paired_end_detection.txt",
    output:
        "{folder}/{sample}/strandphaser/StrandPhaseR.{chrom}.config",
    log:
        "{folder}/log/strandphaser/{sample}/StrandPhaseR.{chrom}.log",
    conda:
        "../envs/mc_base.yaml"
    script:
        "../scripts/strandphaser_scripts/prepare_strandphaser.py"


def bsgenome_install(wildcards):
    if config["reference"] == "T2T":
        return "workflow/data/ref_genomes/config/T2T_R_tarball_install.ok"
    else:
        return "workflow/data/ref_genomes/config/fake_install.ok"


rule run_strandphaser_per_chrom:
    """
    rule fct: run strandphaser for each chromosome 
    input: strandphaser_input.txt from rule convert_strandphaser_input ; genotyped snv for each chrom by freebayes ; configfile created by rule prepare_strandphaser_config_per_chrom ; bam folder
    output:
    """
    input:
        install_strandphaser=rules.install_rlib_strandphaser.output,
        wcregions="{folder}/{sample}/strandphaser/strandphaser_input.txt",
        snppositions=locate_snv_vcf,
        configfile="{folder}/{sample}/strandphaser/StrandPhaseR.{chrom}.config",
        bsgenome=bsgenome_install
    output:
        "{folder}/{sample}/strandphaser/StrandPhaseR_analysis.{chrom}/Phased/phased_haps.txt",
        "{folder}/{sample}/strandphaser/StrandPhaseR_analysis.{chrom}/VCFfiles/{chrom}_phased.vcf",
    log:
        "{folder}/log/run_strandphaser_per_chrom/{sample}/{chrom}.log",
    conda:
        "../envs/rtools.yaml"
    resources:
        mem_mb=get_mem_mb_heavy,
    params:
        input_bam=lambda wc: "{}/{}/bam".format(config["data_location"], wc.sample),
        output=lambda wc: "{}/{}/strandphaser/StrandPhaseR_analysis.{}".format(
            config["data_location"], wc.sample, wc.chrom
        ),
    shell:
        """
        Rscript workflow/scripts/strandphaser_scripts/StrandPhaseR_pipeline.R \
                {params.input_bam} \
                {params.output} \
                {input.configfile} \
                {input.wcregions} \
                {input.snppositions} \
                $(pwd)/utils/R-packages/ > {log} 2>&1
        """


rule merge_strandphaser_vcfs:
    input:
        vcfs=ancient(aggregate_vcf_gz),
        tbis=ancient(aggregate_vcf_gz_tbi),
    output:
        vcfgz="{folder}/{sample}/strandphaser/phased-snvs/{sample}.vcf.gz",
    log:
        "{folder}/log/merge_strandphaser_vcfs/{sample}.log",
    conda:
        "../envs/mc_bioinfo_tools.yaml"
    resources:
        mem_mb=get_mem_mb,
    shell:
        """
        (bcftools concat -a {input.vcfs} | bcftools view -o {output.vcfgz} -O z --genotype het --types snps - ) > {log} 2>&1
        """


rule combine_strandphaser_output:
    input:
        files=aggregate_phased_haps,
    output:
        "{folder}/{sample}/strandphaser/strandphaser_phased_haps_merged.txt",
    log:
        "{folder}/log/combine_strandphaser_output/{sample}.log",
    resources:
        mem_mb=get_mem_mb,
    conda:
        "../envs/mc_base.yaml"
    script:
        "../scripts/strandphaser_scripts/combine_strandphaser_output.py"


rule convert_strandphaser_output:
    input:
        phased_states="{folder}/{sample}/strandphaser/strandphaser_phased_haps_merged.txt",
        initial_states="{folder}/{sample}/segmentation/Selection_initial_strand_state",
        info="{folder}/{sample}/counts/{sample}.info",
    output:
        "{folder}/{sample}/strandphaser/StrandPhaseR_final_output.txt",
    log:
        "{folder}/log/convert_strandphaser_output/{sample}.log",
    conda:
        "../envs/rtools.yaml"
    resources:
        mem_mb=get_mem_mb,
    script:
        "../scripts/strandphaser_scripts/helper.convert_strandphaser_output.R"
