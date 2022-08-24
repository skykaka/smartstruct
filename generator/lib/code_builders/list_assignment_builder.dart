
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';
import 'package:smartstruct_generator/models/source_assignment.dart';
import 'package:source_gen/source_gen.dart';

import 'nested_mapping_builder.dart';

generateListAssignment(SourceAssignment sourceAssignment,
    ClassElement abstractMapper, VariableElement targetField
) {
  final sourceField = sourceAssignment.field!;
  final sourceReference = refer(sourceAssignment.sourceName!);

  final sourceListType = _getGenericTypes(sourceField.type).first;
  final targetListType = _getGenericTypes(targetField.type).first;
  final nestedMapping = findMatchingMappingMethod(
      abstractMapper, targetListType, sourceListType);

  var sourceIsNullable = sourceListType.nullabilitySuffix == NullabilitySuffix.question;
  var targetIsNullable = targetListType.nullabilitySuffix == NullabilitySuffix.question; 
  var needTargetFilter = sourceIsNullable && !targetIsNullable;
  if (nestedMapping != null) {
    final returnIsNullable = checkNestMappingReturnNullable(nestedMapping, sourceIsNullable);
    needTargetFilter = !targetIsNullable && returnIsNullable; 
  }

  // mapping expression, default is just the identity,
  // for example for primitive types or objects that do not have their own mapping method
  final expr = nestedMapping == null ?
    refer('(e)=>e') :
    generateNestedMappingLambda(sourceListType, nestedMapping);
  Expression sourceFieldAssignment =
      // source.{field}.map
    sourceReference.property(sourceField.name)
    .property('map')
    // (expr)
    .call([expr]);

  if(needTargetFilter) {
    sourceFieldAssignment = sourceFieldAssignment.property("where").call([refer("(x) => x != null")]);
  }

  if(sourceAssignment.needCollect(targetField.type)) {
    sourceFieldAssignment = sourceFieldAssignment
      //.toList() .toSet()
      .property(sourceAssignment.collectInvoke(targetField.type))
      // .property('toList')
      // .call([])
      ;
  }

  if(needTargetFilter) {
    sourceFieldAssignment = sourceFieldAssignment
      .asA(refer(targetField.type.getDisplayString(withNullability: true)));
  }

  return sourceFieldAssignment;
}

Iterable<DartType> _getGenericTypes(DartType type) {
  return type is ParameterizedType ? type.typeArguments : const [];
}

checkNestMappingReturnNullable(MethodElement method, bool inputNullable) {
  final returnIsNullable = 
    (inputNullable && 
      method.parameters.first.type.nullabilitySuffix != NullabilitySuffix.question
    ) ||
    (
      inputNullable &&
      method.returnType.nullabilitySuffix == NullabilitySuffix.question
    );
    return returnIsNullable;
}