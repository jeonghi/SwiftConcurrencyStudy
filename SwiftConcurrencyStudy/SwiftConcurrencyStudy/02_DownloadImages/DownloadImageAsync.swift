//
//  DownloadImageAsync.swift
//  SwiftConcurrencyStudy
//
//  Created by 쩡화니 on 8/11/24.
//

import SwiftUI
import Combine


// 이미지 불러오는 역할을 담당하는 녀석 하나
protocol AsyncImageDownloaderType {
  var url: URL { get }
  
  func downloadWithEscaping(completion: @escaping (_ image: UIImage?, _ error: Error?) -> ())
  func downloadWithCombine() -> AnyPublisher<UIImage?, Error>
  func downloadWithAsync() async throws -> UIImage?
}

final class AsyncImageDownloader: AsyncImageDownloaderType {
  
  var url = URL(string: "https://chandra.harvard.edu/photo/2017/a3411/a3411_4k.jpg")!
  
  func downloadWithEscaping(completion: @escaping (UIImage?, (any Error)?) -> ()) {
    URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
      let image = self?.handleResponse(data: data, response: response)
//      DispatchQueue.main.async {
        completion(image, error)
//      }
    }
    .resume()
  }
  
  func downloadWithAsync() async throws -> UIImage? {
    do {
      let (data, response) = try await URLSession.shared.data(from: url, delegate: nil)
      return handleResponse(data: data, response: response)
    } catch {
      throw error
    }
  }
  
  func downloadWithCombine() -> AnyPublisher<UIImage?, Error> {
    URLSession.shared.dataTaskPublisher(for: url)
      .map(handleResponse)
      .mapError({ $0 })
      .eraseToAnyPublisher()
  }
}

extension AsyncImageDownloader {
  private func handleResponse(data: Data?, response: URLResponse?) -> UIImage? {
    guard
      let data,
      let image = UIImage(data: data),
      let response = response as? HTTPURLResponse,
      (200..<300) ~= response.statusCode else {
      return nil
    }
    return image
  }
}

// 뷰 모델 하나와
// 뷰 모델의 비즈니스 로직? : 이미지 fetch 해오기
class DownloadImageAsyncViewModel: ObservableObject {
  
  // State
  @Published var image: UIImage?
  
  // Propeties
  let imageDownloader: AsyncImageDownloaderType = AsyncImageDownloader()
  var cancellables = Set<AnyCancellable>()
  
  deinit {
    cancellables.removeAll()
  }
  
  func fetchImageWithAsync() async {
    let image = try? await imageDownloader.downloadWithAsync()
    await MainActor.run {
      self.image = image
    }
  }
  
  func fetchImageWithCombine() {
    imageDownloader.downloadWithCombine()
      .receive(on: DispatchQueue.main)
      .sink { _ in
        
      } receiveValue: { [weak self] image in
          self?.image = image
      }
      .store(in: &cancellables)
  }
}


// 뷰 하나
struct DownloadImageAsyncView: View {
  
  @StateObject var viewModel: DownloadImageAsyncViewModel = .init()
  @State var isShowing: Bool = false
  
  var body: some View {
    VStack {
      ZStack {
        GeometryReader { geometry in
          if let image = viewModel.image {
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: geometry.size.width, height: geometry.size.height)
              
          }
        }
      }
      .background(Color.black)
      .aspectRatio(1, contentMode: .fit)
      .padding(10)
      Button("눌러질까용") {
        isShowing.toggle()
      }
    }
    .sheet(isPresented: $isShowing) {
      Text("눌러지네용")
    }
    .onAppear {
//      Task {
//        await viewModel.fetchImageWithAsync()
//      }
      Task {
        viewModel.fetchImageWithCombine()
      }
    }
    .onDisappear {
      viewModel.cancellables.removeAll()
    }
  }
}

#Preview {
  DownloadImageAsyncView()
}
