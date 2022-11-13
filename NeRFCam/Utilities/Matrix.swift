//
//  Matrix.swift
//  NeRFCam
//
//  Created by Manuel Concepcion Brito on 3/11/22.
//
import ARKit

struct ExtrinsicMatrix: Codable {
    let col0: SIMD4<Float>
    let col1: SIMD4<Float>
    let col2: SIMD4<Float>
    let col3: SIMD4<Float>
    
    init() {
        col0 = .zero
        col1 = .zero
        col2 = .zero
        col3 = .zero
    }
    
    init(_ matrix: simd_float4x4) {
        let columns = matrix.columns
        col0 = columns.0
        col1 = columns.1
        col2 = columns.2
        col3 = columns.3
    }
}

struct IntrinsicMatrix: Codable {
    let col0: SIMD3<Float>
    let col1: SIMD3<Float>
    let col2: SIMD3<Float>
    
    init() {
        col0 = .zero
        col1 = .zero
        col2 = .zero
    }
    
    init(_ matrix: simd_float3x3) {
        // NeRF Studio gets the rows so just transpose the matrix
        let columns = matrix.columns
        col0 = columns.0
        col1 = columns.1
        col2 = columns.2
    }
}
