use dioxus::prelude::*;

#[derive(Debug, Clone, Routable, PartialEq)]
#[rustfmt::skip]
enum Route {
    #[route("/")]
    Home {},
}

const FAVICON: Asset = asset!("/assets/favicon.ico");
const MAIN_CSS: Asset = asset!("/assets/main.css");
const TAILWIND_CSS: Asset = asset!("/assets/tailwind.css");
const HEADER_SVG: Asset = asset!("/assets/header.svg");

fn main() {
    dioxus::launch(App);
}

#[component]
fn App() -> Element {
    rsx! {
        document::Link { rel: "icon", href: FAVICON }
        document::Link { rel: "stylesheet", href: MAIN_CSS }
        document::Link { rel: "stylesheet", href: TAILWIND_CSS }
        Router::<Route> {}
    }
}

/// Home page - Image Gallery
#[component]
fn Home() -> Element {
    rsx! {
        div { class: "container mx-auto p-8",
            h1 { class: "text-4xl font-bold mb-8 text-center", "Image Gallery" }
            div { class: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6",
                // Example image card with header.svg
                div { class: "bg-white rounded-lg shadow-lg overflow-hidden hover:shadow-xl transition-shadow",
                    div { class: "p-4",
                        img {
                            src: HEADER_SVG,
                            alt: "Header Image",
                            class: "w-full h-64 object-contain",
                        }
                        h3 { class: "mt-4 text-xl font-semibold", "Header SVG" }
                        p { class: "mt-2 text-gray-600", "Sample SVG image from assets" }
                    }
                }
                // Placeholder for more images - you can add your own images here
                div { class: "bg-white rounded-lg shadow-lg overflow-hidden hover:shadow-xl transition-shadow",
                    div { class: "p-4",
                        div { class: "w-full h-64 bg-gradient-to-br from-blue-400 to-purple-500 flex items-center justify-center text-white text-2xl font-bold",
                            "Add Image 1"
                        }
                        h3 { class: "mt-4 text-xl font-semibold", "Your Image Here" }
                        p { class: "mt-2 text-gray-600", "Add your own image to assets folder" }
                    }
                }
                div { class: "bg-white rounded-lg shadow-lg overflow-hidden hover:shadow-xl transition-shadow",
                    div { class: "p-4",
                        div { class: "w-full h-64 bg-gradient-to-br from-green-400 to-blue-500 flex items-center justify-center text-white text-2xl font-bold",
                            "Add Image 2"
                        }
                        h3 { class: "mt-4 text-xl font-semibold", "Your Image Here" }
                        p { class: "mt-2 text-gray-600", "Add your own image to assets folder" }
                    }
                }
                div { class: "bg-white rounded-lg shadow-lg overflow-hidden hover:shadow-xl transition-shadow",
                    div { class: "p-4",
                        div { class: "w-full h-64 bg-gradient-to-br from-pink-400 to-red-500 flex items-center justify-center text-white text-2xl font-bold",
                            "Add Image 3"
                        }
                        h3 { class: "mt-4 text-xl font-semibold", "Your Image Here" }
                        p { class: "mt-2 text-gray-600", "Add your own image to assets folder" }
                    }
                }
            }
            div { class: "mt-12 text-center text-gray-600",
                p { "To add more images:" }
                ol { class: "list-decimal list-inside mt-4 space-y-2",
                    li { "Add your image files to the assets/ folder" }
                    li { "Define them as constants using asset!() macro" }
                    li { "Add new image cards to the grid above" }
                }
            }
        }
    }
}
