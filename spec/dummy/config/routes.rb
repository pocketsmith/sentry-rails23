ActionController::Routing::Routes.draw do |map|
  # Test routes
  map.resources :posts, :member => { :boom => :get }
  map.root :controller => 'posts', :action => 'index'
end