#!/usr/bin/env nextflow
nextflow.preview.dsl=2
name='sanger-wgs-variant-calling'
short_name='sanger-wgs'
version='0.1.0-dev'

/*
========================================================================================
                    ICGC-ARGO Sanger WGS Variant Calling Pipeline
========================================================================================
#### Homepage / Documentation
https://github.com/icgc-argo/sanger-wgs-variant-calling
#### Authors
Junjun Zhang @junjun-zhang <junjun.zhang@oicr.on.ca>
Linda Xiang @lindaxiang <linda.xiang@oicr.on.ca>
----------------------------------------------------------------------------------------

Required Parameters (no default):
--study_id                              SONG study ID
--tumour_aln_analysis_id                Tumour WGS sequencing_alignment SONG analysis ID
--normal_aln_analysis_id                Normal WGS sequencing_alignment SONG analysis ID
--ref_genome_fa                         Reference genome '.fa' file, secondary file ('.fa.fai') is expected to be under the same folder
--ref_genome_tar                        Tarball containing reference genome files from the same genome build
--vagrent_annot                         Tarball containing VAGrENT annotation reference
--ref_cnv_sv_tar                        Tarball containing CNV/SV reference
--ref_snv_indel_tar                     Tarball containing SNV/Indel reference
--qcset_tar                             Tarball containing QC Genotype reference
--song_url                              SONG server URL
--score_url                             SCORE server URL
--api_token                             SONG/SCORE API Token

General Parameters (with defaults):
--cpus                                  cpus given to all process containers (default 1)
--mem                                   memory (GB) given to all process containers (default 1)

Download Parameters (object):
--download
{
    song_container_version              song docker container version, defaults set below
    score_container_version             score docker container version, defaults set below
    song_url                            song url for download process (defaults to main song_url param)
    score_url                           score url for download process (defaults to main score_url param)
    api_token                           song/score API token for download process (defaults to main api_token param)
    song_cpus
    song_mem
    score_cpus
    score_mem
    score_transport_mem
}

generateBas Parameters (object):
--generateBas
{
    container_version                   docker container version, defaults to unset
    cpus                                cpus for seqDataToLaneBam container, defaults to cpus parameter
    mem                                 memory (GB) for seqDataToLaneBam container, defaults to mem parameter
}

sangerWgsVariantCaller Parameters (object):
--sangerWgsVariantCaller
{
    container_version                   docker container version, defaults to unset
    cpus                                cpus for bwaMemAligner container, defaults to cpus parameter
    mem                                 memory (GB) for bwaMemAligner container, defaults to mem parameter
    exclude                             reference contigs to exclude, default: 'chrUn%,HLA%,%_alt,%_random,chrM,chrEBV'
    ploidy                              ploidy estimate of the genome, default: 2.0
    purity                              purity estimate of the genome, default: 1.0
}

repackSangerResults Parameters (object):
--repackSangerResults
{
    container_version                   docker container version, defaults to unset
    cpus                                cpus for bamMergeSortMarkdup container, defaults to cpus parameter
    mem                                 memory (GB) for bamMergeSortMarkdup container, defaults to mem parameter
    library_strategy                    library strategy of input reads, default: WGS
}

payloadGenVariantCall (object):
--payloadGenVariantCall
{
    container_version                   docker container version, defaults to unset
    cpus                                cpus for align container, defaults to cpus parameter
    mem                                 memory (GB) for align container, defaults to mem parameter
}

Upload Parameters (object):
--upload
{
    song_container_version              song docker container version, defaults set below
    score_container_version             score docker container version, defaults set below
    song_url                            song url for upload process (defaults to main song_url param)
    score_url                           score url for upload process (defaults to main score_url param)
    api_token                           song/score API token for upload process (defaults to main api_token param)
    song_cpus                           cpus for song container, defaults to cpus parameter
    song_mem                            memory (GB) for song container, defaults to mem parameter
    score_cpus                          cpus for score container, defaults to cpus parameter
    score_mem                           memory (GB) for score container, defaults to mem parameter
    score_transport_mem                 memory (GB) for score_transport, defaults to mem parameter
    extract_cpus                        cpus for extract container, defaults to cpus parameter
    extract_mem                         memory (GB) extract score container, defaults to mem parameter
}

*/

params.study_id = ""
params.tumour_aln_analysis_id = ""
params.normal_aln_analysis_id = ""
params.ref_genome_fa = ""
params.cleanup = true

params.cpus = 1
params.mem = 1

download_params = [
    'song_container_version': '4.0.0',
    'score_container_version': '3.0.1',
    'song_url': params.song_url,
    'score_url': params.score_url,
    'api_token': params.api_token,
    *:(params.download ?: [:])
]

generateBas_params = [
    *:(params.generateBas ?: [:])
]

sangerWgsVariantCaller_params = [
    'cpus': params.cpus,
    'mem': params.mem,
    'species': 'human',
    'assembly': 'GRCh38',
    'cavereads': 800000,
    'exclude': 'chrUn%,HLA%,%_alt,%_random,chrM,chrEBV',
    'ploidy': 2.0,
    'purity': 1.0,
    'skipqc': false,
    'pindelcpu': 8,
    'ref_genome_tar': '',
    'vagrent_annot': '',
    'ref_snv_indel_tar': '',
    'ref_cnv_sv_tar': '',
    'qcset_tar': '',
    *:(params.sangerWgsVariantCaller ?: [:])
]

repackSangerResults_params = [
    'library_strategy': 'WGS',
    *:(params.repackSangerResults ?: [:])
]

extractSangerCall_params = [
    *:(params.extractSangerCall ?: [:])
]

payloadGenVariantCall_params = [
    *:(params.payloadGenVariantCall ?: [:])
]

payloadGenQcMetrics_params = [
    *:(params.payloadGenVariantCall ?: [:])
]

upload_params = [
    'song_container_version': '4.0.0',
    'score_container_version': '3.0.1',
    'song_url': params.song_url,
    'score_url': params.score_url,
    'api_token': params.api_token,
    *:(params.uploadVariant ?: [:])
]


// Include all modules and pass params
include { songScoreDownload as dnldT; songScoreDownload as dnldN } from './song-score-utils/song-score-download' params(download_params)
include { generateBas as basT; generateBas as basN; } from './modules/raw.githubusercontent.com/icgc-argo/variant-calling-tools/generate-bas.0.2.0.0/tools/generate-bas/generate-bas' params(generateBas_params)
include sangerWgsVariantCaller as sangerWgs from './modules/raw.githubusercontent.com/icgc-argo/variant-calling-tools/sanger-wgs-variant-caller.2.1.0-4/tools/sanger-wgs-variant-caller/sanger-wgs-variant-caller' params(sangerWgsVariantCaller_params)
include repackSangerResults as repack from './modules/raw.githubusercontent.com/icgc-argo/variant-calling-tools/repack-sanger-results.0.2.0.0/tools/repack-sanger-results/repack-sanger-results' params(repackSangerResults_params)
include { extractFilesFromTarball as extractVarSnv; extractFilesFromTarball as extractVarIndel; extractFilesFromTarball as extractVarCnv; extractFilesFromTarball as extractVarSv; extractFilesFromTarball as extractQC } from './modules/raw.githubusercontent.com/icgc-argo/data-processing-utility-tools/extract-files-from-tarball.0.2.0.0/tools/extract-files-from-tarball/extract-files-from-tarball' params(extractSangerCall_params)
include { payloadGenVariantCalling as pGenVarSnv; payloadGenVariantCalling as pGenVarIndel; payloadGenVariantCalling as pGenVarCnv; payloadGenVariantCalling as pGenVarSv  } from "./modules/raw.githubusercontent.com/icgc-argo/data-processing-utility-tools/payload-gen-variant-calling.0.1.0.0/tools/payload-gen-variant-calling/payload-gen-variant-calling.nf" params(payloadGenVariantCall_params)
//include { payloadGenSangerQC as pGenQC } from "./modules/raw.githubusercontent.com/icgc-argo/data-processing-utility-tools/payload-gen-dna-seq-qc.0.2.0.0/tools/payload-gen-dna-seq-qc/payload-gen-dna-seq-qc.nf" params(payloadGenQcMetrics_params)
include { songScoreUpload as upVarSnv; songScoreUpload as upVarIndel; songScoreUpload as upVarCnv; songScoreUpload as upVarSv; songScoreUpload as upQC} from './song-score-utils/song-score-upload' params(upload_params)
include cleanupWorkdir as cleanup from './modules/raw.githubusercontent.com/icgc-argo/nextflow-data-processing-utility-tools/b45093d3ecc3cb98407549158c5315991802526b/process/cleanup-workdir'


def getSecondaryFiles(main_file, exts){  //this is kind of like CWL's secondary files
  def all_files = []
  for (ext in exts) {
    all_files.add(main_file + ext)
  }
  return all_files
}

workflow SangerWgs {
    take:
        study_id
        tumour_aln_analysis_id
        normal_aln_analysis_id
        ref_genome_fa

    main:
        // download tumour aligned seq and metadata from song/score (analysis type: sequencing_alignment)
        dnldT(study_id, tumour_aln_analysis_id)

        // download normal aligned seq and metadata from song/score (analysis type: sequencing_alignment)
        dnldN(study_id, normal_aln_analysis_id)

        // generate Bas for tumour
        basT(
            dnldT.out.files.flatten().first(), dnldT.out.files.flatten().last(),
            file(ref_genome_fa), Channel.fromPath(getSecondaryFiles(ref_genome_fa, ['.fai']), checkIfExists: false).collect())

        // generate Bas for normal
        basN(
            dnldN.out.files.flatten().first(), dnldN.out.files.flatten().last(),
            file(ref_genome_fa), Channel.fromPath(getSecondaryFiles(ref_genome_fa, ['.fai']), checkIfExists: false).collect())


        sangerWgs(
            file(params.sangerWgsVariantCaller.ref_genome_tar),
            file(params.sangerWgsVariantCaller.vagrent_annot),
            file(params.sangerWgsVariantCaller.ref_snv_indel_tar),
            file(params.sangerWgsVariantCaller.ref_cnv_sv_tar),
            file(params.sangerWgsVariantCaller.qcset_tar),
            dnldT.out.files.flatten().first(),  // aln seq
            dnldT.out.files.flatten().last(),
            basT.out.bas_file,  // bas
            dnldN.out.files.flatten().first(),  // aln seq
            dnldN.out.files.flatten().last(),  // idx
            basN.out.bas_file  // bas
        )

        // repack results
        repack(sangerWgs.out.result_archive, 'WGS')

        // extract variant calls
        extractVarSnv(repack.out.caveman, 'flagged.muts')
        extractVarIndel(repack.out.pindel, 'flagged')
        extractVarCnv(repack.out.ascat, 'copynumber.caveman')
        extractVarSv(repack.out.brass, 'annot')

        pGenVarSnv(dnldN.out.song_analysis, dnldT.out.song_analysis, extractVarSnv.out.extracted_files, name, short_name, version)
        pGenVarIndel(dnldN.out.song_analysis, dnldT.out.song_analysis, extractVarIndel.extracted_files, name, short_name, version)
        pGenVarCnv(dnldN.out.song_analysis, dnldT.out.song_analysis, extractVarCnv.out.extracted_files, name, short_name, version)
        pGenVarSv(dnldN.out.song_analysis, dnldT.out.song_analysis, extractVarSv.out.extracted_files, name, short_name, version)

        // upload variant results
        upVarSnv(study_id, pGenVarSnv.out.payload, extractVarSnv.out.extracted_files)
        upVarIndel(study_id, pGenVarIndel.out.payload, extractVarIndel.out.extracted_files)
        upVarCnv(study_id, pGenVarCnv.out.payload, extractVarCnv.out.extracted_files)
        upVarSv(study_id, pGenVarSv.out.payload, extractVarSv.out.extracted_files)


/*
        // more to flesh out
        qc_result_patterns = Channel.from(
            '???', '???')
        extractQC(repack.out.collect(), qc_result_patterns.flatten())

        payloadGenSangerQC(dnldT.out.song_analysis, extractQC.out)

        upQC(study_id, payloadGenSangerQC.out.payload, extractQC.out)
        */


        if (params.cleanup) {
            cleanup(
                dnldT.out.files.concat(dnldN.out, basT.out, basN.out, sangerWgs.out,
                    repack.out, extractVarSnv.out, extractVarIndel.out, extractVarCnv.out, extractVarSv.out).collect(),
                upVarSv.out.analysis_id.concat(upVarSnv.out.analysis_id, upVarIndel.out.analysis_id, upVarCnv.out.analysis_id).collect()
        }

}


workflow {
    SangerWgs(
        params.study_id,
        params.tumour_aln_analysis_id,
        params.normal_aln_analysis_id,
        params.ref_genome_fa
    )
}