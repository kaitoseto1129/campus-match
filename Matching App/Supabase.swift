//
//  Supabase.swift
//  NaviMe
//
//  Created by Kaito Seto on 2026/07/20.
//

import Foundation
import Supabase

func supabase() -> SupabaseClient {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .formatted(formatter)
    
    return SupabaseClient(
        supabaseURL: URL(string: "https://mqmhzroizlszdeoqxydg.supabase.co")!,
          supabaseKey: "sb_publishable_W5_v1sAFCRWrckJ1zAwU4Q_OEuhFl4S",
        options: SupabaseClientOptions( db: SupabaseClientOptions.DatabaseOptions(encoder: encoder,decoder: decoder))
      )
}




