# Copyright © 2017 Intel Corporation
# SPDX-License-Identifier: MIT

inc_gbm = include_directories('.', 'main', 'backends/dri')

files_gbm = files(
  'main/backend.c',
  'main/backend.h',
  'main/gbm.c',
  'main/gbm.h',
  'main/gbmint.h',
)
deps_gbm = []
args_gbm = [
  '-DDEFAULT_BACKENDS_PATH="@0@"'.format(gbm_backends_path),
]
deps_gbm = []
incs_gbm = [
  include_directories('main'), inc_include, inc_src, inc_loader, inc_gallium, inc_st_dri, inc_gallium_aux
]

# TODO: fix includes to delete this
incs_gbm += inc_mesa

if with_dri2
  files_gbm += files('backends/dri/gbm_dri.c', 'backends/dri/gbm_driint.h')
  deps_gbm += dep_libdrm # TODO: pthread-stubs
endif
if with_platform_wayland
  deps_gbm += dep_wayland_server
  incs_gbm += inc_wayland_drm
endif

libgbm_name = 'gbm'

if with_platform_android and get_option('platform-sdk-version') >= 30
  libgbm_name = 'gbm_mesa'
endif

libgbm = shared_library(
  libgbm_name,
  files_gbm,
  include_directories : incs_gbm,
  c_args : [args_gbm],
  link_args : [ld_args_gc_sections],
  link_with : [libloader, libgallium_dri],
  dependencies : [deps_gbm, dep_dl, dep_thread, idep_mesautil, idep_xmlconfig],
  gnu_symbol_visibility : 'hidden',
  version : '1.0.0',
  install : true,
)

if with_tests
  abi_check = executable('gbm_abi_check', 'main/gbm_abi_check.c')
  test('gbm-abi-check', abi_check, suite : ['gbm'])
endif

install_headers('main/gbm.h')

pkg.generate(
  name : 'gbm',
  filebase : 'gbm',
  description : 'Mesa gbm library',
  version : meson.project_version(),
  libraries : libgbm,
  libraries_private : gbm_priv_libs,
  variables : ['gbmbackendspath=' + gbm_backends_path],
)

if with_symbols_check
  test(
    'gbm-symbols-check',
    symbols_check,
    args : [
      '--lib', libgbm,
      '--symbols-file', files('gbm-symbols.txt'),
      symbols_check_args,
    ],
    suite : ['gbm'],
  )
endif
