import pandas as pd

df = pd.read_csv(snakemake.input[0], sep=",", compression="gzip")
df = df[["chrom", "start", "end", "sample", "cell", "c", "w", "class"]]
df["w"] = df["w"].fillna(0)
df["c"] = df["c"].fillna(0)
df["class"] = df["class"].fillna("None")
df["class"] = df["class"].astype(str)
df.to_csv(snakemake.output[0], sep="\t", index=False, compression="gzip")
