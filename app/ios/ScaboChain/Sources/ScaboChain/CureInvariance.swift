//
//  CureInvariance.swift
//  ScaboChain
//
//  I LIBRI CHE UNA CURA NON CAMBIA, MISURATI (giro «rifiniture e cure per capacità», 2026-11-07). La cura della catena si
//  offre ai libri già elaborati con «Lettura migliore disponibile» (§ 12.13): dalla cura 64 l'offerta va a TUTTI E SOLI i
//  libri la cui lettura cambia, nei limiti di quel che si sa senza rielaborarli. Un libro del banco (o un documento di studio)
//  la cui lettura la cura lascia IDENTICA AL BYTE su una generazione del lettore di sistema non riceve l'offerta su quella
//  generazione (`ReprocessingPolicy.unchangedByCure`, ScaboCore); ogni altro libro la riceve, perché la sua lettura può
//  cambiare e senza rielaborarlo non si sa.
//
//  Gli elenchi sono impronte (SHA-256 del file PDF, `ArchivedDocument.sourceSha256`), mai nomi né titoli: si misurano al
//  banco nel giro che porta la cura (catena dell'iPad sulle catture con l'impronta, prima e dopo la cura, cinque file della
//  lettura confrontati al byte per volume e per generazione) e non si toccano più. Una copia diversa dello stesso libro ha
//  un'altra impronta: riceve l'offerta, come un libro sconosciuto.
//

import Foundation

extension ProcessingChain {

    /// Cura → versione maggiore del sistema → impronte dei libri misurati che la cura lascia identici su quella generazione.
    /// 64 (giro «rifiniture e cure per capacità»): 49 volumi del banco su 52 identici con iOS 27 e 48 con iOS 26.5, più i due
    /// documenti di studio delle cure mirate; cambiano tre volumi (un titolo recuperato da una testatina, note con i numeri
    /// in colonna rimesse in ordine) e, con iOS 26.5, un quarto volume (parole col trattino morbido riunite), oltre al
    /// volume della prova alla cieca.
    /// 66 (giro «prova 4, segnalibri e sigle», 2026-11-11, frasi dopo le sigle): 13 volumi del banco su 52 identici, gli stessi
    /// con iOS 26.5 e con iOS 27, più uno dei documenti di studio; misurati sulle cinque forme della lettura a TUTTE e quattro
    /// le granularità (la cura sposta confini di blocco e pezzi di nota, che dipendono dal livello scelto).
    public static let booksUnchangedByCure: [Int: [Int: Set<String>]] = [
        64: [26: unchangedByCure64Common, 27: unchangedByCure64Common.union(unchangedByCure64OnlyOn27)],
        66: [26: unchangedByCure66, 27: unchangedByCure66],
    ]

    /// Cura → impronte (SHA-256 del file XML archiviato) dei TESTI NORMATIVI misurati che la cura lascia identici: la loro
    /// lettura non dipende dal lettore di sistema, quindi un elenco solo per ogni generazione. Come per i PDF, un atto
    /// misurato identico non riceve l'offerta per quella cura; un atto sconosciuto sì.
    /// 66: 12 atti su 14 dei campioni pubblici di Normattiva del repo (cambiano i due con note lunghe che citano decreti e
    /// commi abrogati), misurati ai quattro livelli.
    public static let aknActsUnchangedByCure: [Int: Set<String>] = [
        66: aknActsUnchangedByCure66,
    ]
}

/// Cura 64: identici su iOS 26.5 e su iOS 27 (50 impronte).
private let unchangedByCure64Common: Set<String> = [
    "02b77c581a2ff0ccfdd18af9c97f8012a4fc45eaedfab1020ca63cd7aa6c14dc",
    "07d1c5efbac1550316f2ee77a2d67cd654c0e842cd05861935c05de14cc09d76",
    "0bdf49d845ae2bf6438d80c53ba5ce027fb6671213ece92922171a3e3588fd2d",
    "180f71dbfcfea0d3683350a939d34e8b1ded1f9b28fdcd40401d348fdac59a5f",
    "1be94719c862ffd342d6acc07d06c62dd2ca8b704e1f2b2592b8229fed8a5c27",
    "1d2f19fe609ae5a94b0703a3f53419344b53bc88ddbd776372734e4c3d42ac25",
    "227675b049bc36db5435b8234182204ee05d796c57b6ea2a0e8a54ed73ccae59",
    "2d82f9de4fe61c7bbf07a6db0446a4c356329502d36b5570d5563b6ee812b4ab",
    "31c79c8992534510c6eff13a351f700d6e669e2f506b8ecd411307d3decae8f4",
    "33ae30235eab9f8ca98002e943a86f1a0b9096cf18896858281d0e01548257ee",
    "3ab65ca046b06e2316af364f47d6404735bfa049780e6e0a726a76b9c5f8ffac",
    "3efddd7cba24908275c9fc34cb7f1b007cc402f00a647fd4586bea609c54a416",
    "45fbdcce2468dc09526949f279221f75c37c1f26366de5a0f83dc7c814384f16",
    "469b548c642bb77a944b4af2994b0bf28f53a3b4e2a6bf6c3ffc721e7242a96a",
    "4b7d4b26351642c9aa82289c17b58b1cee4af54f081f7353c411fdf7700aa842",
    "4cb8a060505bef2fb8330ad529e4d72609e605c398d6d23b436d05b9733712e4",
    "5a866fbcf0a2507ddf205532a4fffb1b132d36b996cee57b99862c535167746c",
    "5d58b1cb0900f2b6c345fa7ce2659405ff8af29307b620ff7643938a5c92c11f",
    "5f24fa27a4bf84f474bf791335e61db99c91bbd6730d1e860199474236b1a6e3",
    "5ff19429c7e1e515b9250edbf83bc4ea07cc20a0c1f4dad045d0454e8d7d57b3",
    "7b8afc22711a943d18689a49a6ef7de9b3417883084f96f9772673bf0f6ca819",
    "825a7420732740beaa17b42c38d91e4ce48882d8daade2f977542cd2fb507fd6",
    "951a1d329378443b78aec4a2db13834ad1fc51dac4e96a3fe7b08ca9357bbef8",
    "9b685b1052da2a795f9fc9d1174289c7e4c25955870d260a70a85bd0d826d802",
    "9b92f1b13c72a8c3cd2e0e84e7cea0557459154911041867dc8079d7ba399830",
    "9d49de89a20be4cc7af328a711ebf5fcc5e580fe700ca852dee7300239358c52",
    "a68a98581dca30f246824261c7d4dbc9f5031cdee69e2cf351eae05c01cb7bf8",
    "a8d4fe01e9da7ce3f9d2f2551c4675a0fbef9041f6bb9d8907bb441d61e7fa5b",
    "ab52157fa922e610dece81d907535d903971850e0321edcdaa953cfb45fb8d30",
    "ae5ab0bf66f345a26327767a6361964052af1d46083dbea4f27d3b6a19c23da9",
    "b8c6b4b6e72afc50dd386f8f86cbecd7e81abd6654e5d740902ddc8d7001a110",
    "c35a79271f2cadefaebdea928905ce5cad8c957483a5b02c73f7cf1f9596e875",
    "c4b93886c2b04658bafb6d93e725334e667c16ba48031b1b82a5c18fd225fec1",
    "d0272b2123af0ae040045ef2942c9d8414c2a779a3457a0f3087f62de8bca815",
    "d12bb6434c9f80f19ce8ceb7472c37e42082781d219fe7231c806f1623dcbf1d",
    "d1c76b81f8deb2a022f056d6953644fb8157ba57a725fca4c1111b7639ff24be",
    "d8ba8825c23869ed0ff58800ca331e0d4adbaef23fdc6abe8d0f883aa78c7c87",
    "e0a05d7e91b783d2948d6d188f0de149ebc3f4a79627e5e3cbd493b9f5a0b14e",
    "e1fd3849832bb2fd5e0879329057c7125371c7ffab734c0e3c7af4dc4c051f7f",
    "e33d7fc840fce15be4927d1dc1187d5c6c8665883b4d00e569b2786a31032f32",
    "e9107b7cc7fc9483c86b0d36578664e3bda09973465adaf416303a6d50dbd914",
    "e958e0daa55a90dd0a276cef4f00180918c8592046e63287c51beab210f82475",
    "ecab1854283b7e61bc101a15339c417eb988551f70fdd039c130370d784e733a",
    "ecccbf4cc0cb5078350d87cef6df986bd81846ebe7da07a34536f890c0498bff",
    "ed85e38364f4fb78f93731e09166cfb88673168fe6895c6ca9b3d3e5b5804d7e",
    "f077dedd34727c3aa147e3113840c56701fa594ed5831f4344103ff9d1440c4e",
    "f0a98bcdcd46a5af734f8879a2d10d36de172200896c4e7e1ab9f885cc83a6a4",
    "f151e9af1b2e6fd1f1fde095f230527eb517b542827a53387f10acd278e4d0ff",
    "f222d2072083b80e4cee088e9b9acb55dadf0e97b317b58697509301a7574253",
    "f3842fbd1973d73ae186d615cd87a9f5274649cee96a76939de5934268468b62",
]

/// Cura 64: identici solo su iOS 27 (1 impronta: con iOS 26.5 la cura riunisce le parole col trattino morbido).
private let unchangedByCure64OnlyOn27: Set<String> = [
    "d301c63e306a83aff75713e20dac24eaed960b33c06d7d9698e097ed642cbe90",
]

/// Cura 66: identici su iOS 26.5 e su iOS 27 (14 impronte: 13 volumi del banco e un documento di studio).
private let unchangedByCure66: Set<String> = [
    "180f71dbfcfea0d3683350a939d34e8b1ded1f9b28fdcd40401d348fdac59a5f",
    "2d82f9de4fe61c7bbf07a6db0446a4c356329502d36b5570d5563b6ee812b4ab",
    "3efddd7cba24908275c9fc34cb7f1b007cc402f00a647fd4586bea609c54a416",
    "469b548c642bb77a944b4af2994b0bf28f53a3b4e2a6bf6c3ffc721e7242a96a",
    "4cb8a060505bef2fb8330ad529e4d72609e605c398d6d23b436d05b9733712e4",
    "5a866fbcf0a2507ddf205532a4fffb1b132d36b996cee57b99862c535167746c",
    "951a1d329378443b78aec4a2db13834ad1fc51dac4e96a3fe7b08ca9357bbef8",
    "a68a98581dca30f246824261c7d4dbc9f5031cdee69e2cf351eae05c01cb7bf8",
    "a8d4fe01e9da7ce3f9d2f2551c4675a0fbef9041f6bb9d8907bb441d61e7fa5b",
    "d0272b2123af0ae040045ef2942c9d8414c2a779a3457a0f3087f62de8bca815",
    "d12bb6434c9f80f19ce8ceb7472c37e42082781d219fe7231c806f1623dcbf1d",
    "d1c76b81f8deb2a022f056d6953644fb8157ba57a725fca4c1111b7639ff24be",
    "e9107b7cc7fc9483c86b0d36578664e3bda09973465adaf416303a6d50dbd914",
    "e958e0daa55a90dd0a276cef4f00180918c8592046e63287c51beab210f82475",
]

/// Cura 66: testi normativi identici (12 impronte dei campioni pubblici di Normattiva).
private let aknActsUnchangedByCure66: Set<String> = [
    "1568eb0d9306ba8fde971e09106a6900001d89314e15bc4933609f14cd29abb2",
    "3250d70dcdb2043bf479aecf38ee584e6211d33504ffd883956c9f2f9157924a",
    "5a1b8cfc26b9408d32c332b54efc25c7fea85a0a3af43ca8a7460e4ab7e9536e",
    "7574cd763a984ead3ccbc5d2fcf969f65c88edb44460aea53f2107721e54669c",
    "9411a5202126703fe307f7ea3ac7f00fcddcabcb8db16024a89325c57ff9477b",
    "9a98959ea9c5cf3b766347141e9c7d3a4223e4008b9b6411387aeffff15f9810",
    "b05f0baf49c4b4e76b9da215f18a07c9fd91aae0f1d5b25e4096634208c67a4d",
    "c47ab40c396376a2f7061c772dc109a14fc971d5b3c779c3e3f4cc6adbe656bc",
    "d33282e4cc5b3c48cd0c214703d3d92c2229abfc37d2684672028743b33d3487",
    "de5665ff7a3aab7e9be905ed663c1a65253626ed7b49f582c806aa473e9bc8a4",
    "e0c77491a2f058c9d2fb05b8e1942e7b3537f06a8b323e3bd9773563b1c0a629",
    "f9fba645d0c704397ca2b67081e927a00cb504b55fae5f205588c90a3c27d24a",
]
