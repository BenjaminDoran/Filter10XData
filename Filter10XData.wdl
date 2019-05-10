workflow Filter10XData {

  # params for FilterData
  File infile # filepath to 10x raw_gene_barcodes.h5
  String outfile # filepath to output filtered.h5ad
                 # recommended "gs://bucket/filtered/<smp_id>.h5ad"
  String smp_id # unique sample id
  Int? max_count=20000 # threshold
  Int? max_genes=3000 # threshold
  Int? min_cells=3 # threshold
  Int? min_genes=200 # threshold


  # params for MakeFilterPlots
  String figdir # directory that figures should be output
  String? outpdf="${smp_id}.pdf" # filename of outpdf (not path)
  # if you want each pdf as a separate file set to "${smp_id}.pdf"
  String? outpng="${smp_id}.png" # filename of outpng (not path)
  # not needed because they match args needed for FilterData or its outputs
  # infile=infile
  # smp_id=smp_id
  # filterbarcodes=FilterData.filterbarcodes

  # params for runtimes
  String? zones = "us-east1-d us-west1-a us-west1-b us-central1-b"
  Int? num_cpu = 8
  String? memory = "10G"
  Int? disk_space = 12 # in GB
  Int? preemptible = 2 # attempts

  call FilterData {
    input:
      infile=infile,
      outfile=outfile,
      smp_id=smp_id,
      max_count=max_count,
      max_genes=max_genes,
      min_cells=min_cells,
      min_genes=min_genes,
      memory=memory,
      disk_space=disk_space,
      preemptible=preemptible,
      zones=zones,
      num_cpu=num_cpu
  }

  call MakeFilterPlots {
    input:
      infile=infile,
      filterbarcodes=FilterData.filterbarcodes,
      smp_id=smp_id,
      figdir=figdir,
      outpdf=outpdf,
      outpng=outpng,
      memory=memory,
      disk_space=disk_space,
      preemptible=preemptible,
      zones=zones,
      num_cpu=num_cpu
  }

  output {
      File filtered_h5ad = FilterData.filtered_h5ad
      File filtered_pdf = MakeFilterPlots.filtered_pdf
      File filtered_png = MakeFilterPlots.filtered_png
  }
}


task FilterData {
  File infile
  String outfile
  String smp_id

  Int max_count
  Int max_genes
  Int min_cells
  Int min_genes

  String zones
  String memory
  Int num_cpu
  Int disk_space
  Int preemptible

  command <<<

    python << CODE
    import yaml
    params = {"step00_filter_data": {
        "${smp_id}": {
          "max_count": ${max_count},
          "max_genes": ${max_genes},
          "min_cells": ${min_cells},
          "min_genes": ${min_genes}
      }}}
    with open("filter_params.yml", 'w') as yaml_file:
      yaml.dump(params, yaml_file)
    CODE

    python \
    -m scanpy_helpers.wrkfl.step00_filter_data \
      --infile ${infile} \
      --params filter_params.yml \
      --smp_id ${smp_id} \
      --outfile output/filtered.h5ad \
      --filterbarcodes output/filterbarcodes.h5

    gsutil cp output/filtered.h5ad ${outfile}

  >>>

  output {
    File filtered_h5ad = "${outfile}"
    File filterbarcodes = "output/filterbarcodes.h5"
  }

  runtime {
    docker: "shaleklab/scanpy_helpers:0.0.3dev"
    zones: zones
    memory: memory
    bootDiskSizeGb: 12
    disks: "local-disk ${disk_space} HDD"
    cpu: num_cpu
    preemptible: preemptible
  }
}


task MakeFilterPlots {
  File infile
  File filterbarcodes
  String smp_id
  String figdir
  String outpdf
  String outpng

  String zones
  String memory
  Int num_cpu
  Int disk_space
  Int preemptible

  command {
    mkdir tmpfigs
    python -m scanpy_helpers.scrpt.filter_plot \
      --raw-sample ${infile} \
      --filter-barcodes ${filterbarcodes} \
      --smp-id ${smp_id} \
      --outdir tmpfigs \
      --outpdf ${outpdf} \
      --outpng ${outpng}

    gsutil cp tmpfigs/${outpng} ${figdir}/${outpng}
    gsutil cp tmpfigs/${outpdf} ${figdir}/${outpdf}

  }

  output {
    File filtered_pdf = "${figdir}/${outpdf}"
    File filtered_png = "${figdir}/${outpng}"
  }

  runtime {
    docker: "shaleklab/scanpy_helpers:0.0.3dev"
    zones: zones
    memory: memory
    bootDiskSizeGb: 12
    disks: "local-disk ${disk_space} HDD"
    cpu: num_cpu
    preemptible: preemptible
  }
}
