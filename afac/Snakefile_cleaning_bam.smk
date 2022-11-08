# Whoeps 16th Feb 2021
# Snakemake for bringing bams into mosaicatcher-complying format.

# This snakefile contains rules to:
# 1) exchange the SM and ID tag,
# 2) Index the resulting bam files
# 3) Make automatically symlinks from the /all/ to /selected/ folders.

# According to my labbook (check key [BAM sample prep]), here is what bams need to fulfill:

##############################
# 'ID' has to be the same in
# 1) The bam name
# 2) The RG ID thing in the header
# 3) In the end of each individual read.
#
# 'SM' has to be the same in
# 1) The folder name in /bam/
# 2) The header RG SM thing
# 3) The bed file
##############################

from collections import defaultdict

Testmode = False

path_to_orig_samples = "/scratch/tweber/SCO_COURSE/HJ_MIXTURE"


SAMPLE, BAM = glob_wildcards(path_to_orig_samples + "/{sm}/raw/{id}.sort.mdup.bam")
SAMPLES = sorted(set(SAMPLE))
print(SAMPLE)
print(BAM)
# print(ONEKG)

### THIS PART IS STOLEN FROM MOSAICATCHER ###
CELL_PER_SAMPLE = defaultdict(list)
BAM_PER_SAMPLE = defaultdict(list)
for sample, bam in zip(SAMPLE, BAM):
    BAM_PER_SAMPLE[sample].append(bam)
    CELL_PER_SAMPLE[sample].append(bam.replace("_sorted", ""))

ALLBAMS_PER_SAMPLE = BAM_PER_SAMPLE
print(BAM_PER_SAMPLE)

print("Detected {} samples:".format(len(SAMPLES)))
for s in SAMPLES:
    print(
        "  {}:\t{} cells\t {} selected cells".format(
            s, len(ALLBAMS_PER_SAMPLE[s]), len(BAM_PER_SAMPLE[s])
        )
    )
#################################33

# Targets #
bams_all = []
bais_all = []
bams_select = []
bais_select = []
for s in SAMPLES:
    bams_all.extend(
        expand(
            "{path}/{SM}/bam/{ID}.sort.mdup.bam",
            path=path_to_orig_samples,
            SM=s,
            ID=ALLBAMS_PER_SAMPLE[s],
        )
    )
# bais_all.append(
#     expand(
#         "{path}/{SM}/all/{ID}.sort.mdup.bam.bai",
#         path=path_to_orig_samples,
#         SM=s,
#         ID=ALLBAMS_PER_SAMPLE[s],
#     )
# )
# bams_select.append(
#     expand(
#         "{path}/{SM}/selected/{ID}.bam",
#         path=path_to_orig_samples,
#         SM=s,
#         ID=ALLBAMS_PER_SAMPLE[s],
#     )
# )
# bais_select.append(
#     expand(
#         "{path}/{SM}/selected/{ID}.bam",
#         path=path_to_orig_samples,
#         SM=s,
#         ID=ALLBAMS_PER_SAMPLE[s],
#     )
# )


# bams_all = ['HG00513/all/HG00513_IV_045.bam']
rule all:
    input:
        bams_all,
        # bais_all,
        # bams_select,
        # bais_select,


rule change_id_and_sam:
    input:
        # bam_orig=expand(
        #     "{path}/{SM}/raw/{ID}.bam",
        #     zip,
        #     path=path_to_orig_samples,
        #     SM=SAMPLE,
        #     ID=BAM,
        # ),
        bam_orig="{path}/{SM}/raw/{ID}.sort.mdup.bam",
    output:
        bam_out="{path}/{SM}/bam/{ID}.sort.mdup.bam",
    shell:
        """
        # First, the 'ID' tag
        samtools view -H {input.bam_orig} | sed "s/ID:.*\t/ID:{wildcards.ID}\t/" | samtools reheader - {input.bam_orig} > {output.bam_out}pre1
        # next, 'SM' tag. We also have to make a new header
        samtools view -H {output.bam_out}pre1 | sed "s/SM:.*$/SM:{wildcards.SM}/" | samtools reheader - {output.bam_out}pre1 > {output.bam_out}pre2
        # then, RG:Z tag.
        samtools view -h {output.bam_out}pre2 | sed "s/RG:Z:.*/RG:Z:{wildcards.ID}/" > {output.bam_out}.sam
        # sam to bam
        samtools view -Sb {output.bam_out}.sam > {output.bam_out}
        # Remove intermediate files
        rm {output.bam_out}pre1 {output.bam_out}pre2 {output.bam_out}.sam
        """


# rule add_idx:
#     input:
#         bam="{path}/{SM}/all/{ID}.sort.mdup.bam",
#     output:
#         bai="{path}/{SM}/all/{ID}.sort.mdup.bam.bai",
#     shell:
#         """
#         samtools index {input.bam}
#         """
