ActionController::Routing::Routes.draw do |map|
  map.resources :posts, :member => { :error => :get }
  map.root :controller => 'home', :action => 'index'
end