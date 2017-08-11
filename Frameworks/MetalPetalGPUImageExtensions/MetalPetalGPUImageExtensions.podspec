Pod::Spec.new do |s|
s.name         = 'MetalPetalGPUImageExtensions'
s.version      = '1.0'
s.author       = { 'YuAo' => 'me@imyuao.com' }
s.homepage     = 'https://github.com/MetalPetal/MetalPetalGPUImageExtensions'
s.summary      = 'MetalPetal GPUImageExtensions'
s.license      = { :type => 'MIT'}
s.source       = { :git => 'https://github.com/MetalPetal/MetalPetalGPUImageExtensions.git', :tag => s.version}
s.requires_arc = true
s.ios.deployment_target = '9.0'
s.source_files = '**/*.{h,m,c,mm,metal}'
s.dependency 'MetalPetal'
s.dependency 'GPUImage'
end
